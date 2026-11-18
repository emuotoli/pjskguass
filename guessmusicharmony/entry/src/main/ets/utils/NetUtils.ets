import http from '@ohos.net.http';

export class NetUtils {
  private static httpRequest: http.HttpRequest | null = null;

  static createRequest(): http.HttpRequest {
    if (!NetUtils.httpRequest) {
      NetUtils.httpRequest = http.createHttp();
    }
    return NetUtils.httpRequest!;
  }

  static async get(url: string, headers?: Record<string, string>): Promise<{
    statusCode: number;
    body: string;
  }> {
    const request = NetUtils.createRequest();
    const customHeaders: Record<string, string> = {
      'User-Agent': 'Mozilla/5.0 (compatible; ProjectSEKAI-Game/1.0)',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      ...(headers || {})
    };

    const response = await request.request(url, {
      method: http.RequestMethod.GET,
      header: customHeaders,
      connectTimeout: 10000,
      readTimeout: 15000
    });

    return {
      statusCode: response.responseCode,
      body: response.result as string || ''
    };
  }

  static async head(url: string): Promise<boolean> {
    try {
      const request = NetUtils.createRequest();
      const response = await request.request(url, {
        method: http.RequestMethod.HEAD,
        header: {
          'User-Agent': 'Mozilla/5.0'
        },
        connectTimeout: 5000,
        readTimeout: 5000
      });
      return response.responseCode === 200 || response.responseCode === 206;
    } catch (e) {
      return false;
    }
  }

  static async getJson(url: string, headers?: Record<string, string>): Promise<{
    statusCode: number;
    data: Record<string, Object> | null;
  }> {
    try {
      const response = await NetUtils.get(url, headers);
      if (response.statusCode === 200) {
        return {
          statusCode: response.statusCode,
          data: JSON.parse(response.body) as Record<string, Object>
        };
      }
      return { statusCode: response.statusCode, data: null };
    } catch (e) {
      return { statusCode: -1, data: null };
    }
  }

  static destroy(): void {
    if (NetUtils.httpRequest) {
      NetUtils.httpRequest.destroy();
      NetUtils.httpRequest = null;
    }
  }
}
