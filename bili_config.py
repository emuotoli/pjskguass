"""B站凭证配置模块。

为避免账号 Cookie 泄露，脚本不再硬编码 SESSDATA / bili_jct / DedeUserID。
凭证按以下优先级读取：

1. 环境变量 BILIBILI_COOKIE（完整 Cookie 字符串，直接粘贴浏览器里的值）
   或三个独立变量 BILIBILI_SESSDATA / BILIBILI_BILI_JCT / BILIBILI_DEDEUSERID
2. 脚本同目录下的 cookies.local.json（格式见 cookies.example.json）

本地凭证文件 cookies.local.json 已在 .gitignore 中排除，不会被提交到 Git。
未配置任何凭证时返回空字符串，脚本会以游客身份运行（部分接口可能受限）。
"""

import json
import os

_LOCAL_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cookies.local.json")


def get_cookies_dict():
    """返回 cookie 字典，未配置时返回空字典。"""
    # 优先级 1：完整 Cookie 字符串环境变量
    raw = os.environ.get("BILIBILI_COOKIE", "").strip()
    if raw:
        return _parse_cookie_string(raw)

    # 优先级 2：三个独立环境变量
    sessdata = os.environ.get("BILIBILI_SESSDATA", "").strip()
    bili_jct = os.environ.get("BILIBILI_BILI_JCT", "").strip()
    dedeuserid = os.environ.get("BILIBILI_DEDEUSERID", "").strip()
    if sessdata or bili_jct or dedeuserid:
        return {
            "SESSDATA": sessdata,
            "bili_jct": bili_jct,
            "DedeUserID": dedeuserid,
        }

    # 优先级 3：本地凭证文件
    if os.path.exists(_LOCAL_FILE):
        try:
            with open(_LOCAL_FILE, "r", encoding="utf-8") as f:
                data = json.load(f)
            if isinstance(data, dict):
                return {
                    "SESSDATA": str(data.get("SESSDATA", "")),
                    "bili_jct": str(data.get("bili_jct", "")),
                    "DedeUserID": str(data.get("DedeUserID", "")),
                }
        except (OSError, ValueError) as exc:
            print(f"[bili_config] 读取 {_LOCAL_FILE} 失败: {exc}")

    return {}


def get_cookie_string():
    """返回可直接放入请求头 Cookie 字段的字符串，未配置时返回空字符串。"""
    cookies = get_cookies_dict()
    return "; ".join(f"{k}={v}" for k, v in cookies.items() if v)


def _parse_cookie_string(raw):
    result = {}
    for part in raw.split(";"):
        part = part.strip()
        if "=" in part:
            key, value = part.split("=", 1)
            result[key.strip()] = value.strip()
    return result


def is_configured():
    """是否已配置凭证，便于脚本提示用户。"""
    return bool(get_cookies_dict())


if __name__ == "__main__":
    if is_configured():
        print("已检测到 B站凭证配置。")
        print("Cookie 字符串:", get_cookie_string())
    else:
        print("未检测到 B站凭证。请通过环境变量 BILIBILI_COOKIE")
        print("或本地 cookies.local.json 配置（模板见 cookies.example.json）。")
