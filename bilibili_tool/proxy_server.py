"""
B站视频解析下载工具 - 本地代理服务器
同时提供静态文件服务 + B站 API 代理
用法：python proxy_server.py  然后浏览器访问 http://localhost:8765/
"""
import http.server
import socketserver
import urllib.request
import urllib.parse
import json
import os
import sys

PORT = 8765
WEB_DIR = os.path.dirname(os.path.abspath(__file__))

# 需要代理的目标主机白名单
ALLOWED_HOSTS = [
    'api.bilibili.com',
    'i0.hdslb.com', 'i1.hdslb.com', 'i2.hdslb.com',
    'i3.hdslb.com', 'i4.hdslb.com',
]

class ProxyHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB_DIR, **kwargs)

    def end_headers(self):
        # 允许跨域（方便 file:// 直接打开网页时调用）
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', '*')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200)
        self.end_headers()

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)

        # 代理接口：/api/proxy?url=<encoded_url>
        if parsed.path == '/api/proxy':
            self.handle_proxy(parsed)
            return

        # 代理接口（直接路径形式）：/api/bili/...
        if parsed.path.startswith('/api/bili/'):
            target = 'https://api.bilibili.com' + parsed.path[len('/api/bili'):]
            if parsed.query:
                target += '?' + parsed.query
            self.fetch_target(target, is_json=True)
            return

        # 其他请求当作静态文件处理
        super().do_GET()

    def handle_proxy(self, parsed):
        params = urllib.parse.parse_qs(parsed.query)
        target_url = params.get('url', [''])[0]
        if not target_url:
            self.send_error(400, 'Missing url parameter')
            return

        # 安全校验：只允许白名单主机
        try:
            target_parsed = urllib.parse.urlparse(target_url)
            if target_parsed.hostname not in ALLOWED_HOSTS:
                self.send_json(403, {'error': f'Host not allowed: {target_parsed.hostname}'})
                return
        except Exception:
            self.send_json(400, {'error': 'Invalid url'})
            return

        self.fetch_target(target_url, is_json=True)

    def fetch_target(self, target_url, is_json=False):
        try:
            req = urllib.request.Request(target_url, headers={
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                              '(KHTML, like Gecko) Chrome/120.0 Safari/537.36',
                'Referer': 'https://www.bilibili.com/',
                'Accept': 'application/json, text/plain, */*',
            })
            with urllib.request.urlopen(req, timeout=20) as response:
                content = response.read()
                content_type = response.headers.get('Content-Type', 'application/octet-stream')

                self.send_response(200)
                if is_json:
                    self.send_header('Content-Type', 'application/json; charset=utf-8')
                else:
                    self.send_header('Content-Type', content_type)
                self.send_header('Content-Length', str(len(content)))
                self.end_headers()
                self.wfile.write(content)
        except urllib.error.HTTPError as e:
            self.send_json(e.code, {'error': f'Upstream HTTP {e.code}', 'message': str(e)})
        except Exception as e:
            self.send_json(502, {'error': 'Proxy failed', 'message': str(e)})

    def send_json(self, code, obj):
        body = json.dumps(obj, ensure_ascii=False).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)


class ThreadingServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


def main():
    # 自动选择端口：8765 被占用则递增
    port = PORT
    while True:
        try:
            server = ThreadingServer(('0.0.0.0', port), ProxyHandler)
            break
        except OSError:
            port += 1
            if port > PORT + 20:
                print('找不到可用端口')
                sys.exit(1)

    print('=' * 60)
    print('  B站视频解析下载工具 - 本地代理服务器')
    print('=' * 60)
    print(f'  静态文件目录：{WEB_DIR}')
    print(f'  代理端口：    {port}')
    print(f'  访问地址：    http://localhost:{port}/')
    print('=' * 60)
    print('  按 Ctrl+C 停止服务')
    print('=' * 60)

    # Windows 下自动打开浏览器
    try:
        if sys.platform.startswith('win'):
            os.startfile(f'http://localhost:{port}/')
    except Exception:
        pass

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print('\n服务器已停止')
        server.shutdown()


if __name__ == '__main__':
    main()
