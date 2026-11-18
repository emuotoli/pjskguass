// B站视频解析下载工具
// 优先使用本地代理（同源 /api/proxy），公共 CORS 代理作为备用

// 代理列表（按优先级）
const PROXIES = [
  // 本地 Python 代理（同源，最稳定）
  (url) => `/api/proxy?url=${encodeURIComponent(url)}`,
  // 公共 CORS 代理备用
  (url) => `https://api.allorigins.win/raw?url=${encodeURIComponent(url)}`,
  (url) => `https://corsproxy.io/?url=${encodeURIComponent(url)}`,
  (url) => `https://api.codetabs.com/v1/proxy/?quest=${encodeURIComponent(url)}`
];

const BILI_API = {
  view: 'https://api.bilibili.com/x/web-interface/view',
  playurl: 'https://api.bilibili.com/x/player/playurl'
};

// 状态
let currentVideo = null;
let currentStreams = null;
let workingProxyIdx = 0;  // 缓存可用的代理

// DOM 引用
const urlInput = document.getElementById('urlInput');
const parseBtn = document.getElementById('parseBtn');
const statusSection = document.getElementById('statusSection');
const statusMsg = document.getElementById('statusMsg');
const resultSection = document.getElementById('resultSection');

// ============ 工具函数 ============

function formatNumber(n) {
  if (n >= 100000000) return (n / 100000000).toFixed(1) + '亿';
  if (n >= 10000) return (n / 10000).toFixed(1) + '万';
  return String(n);
}

function formatDuration(sec) {
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

function formatDate(ts) {
  const d = new Date(ts * 1000);
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function showStatus(msg, type = 'loading') {
  statusSection.classList.remove('hidden');
  statusMsg.className = 'status-msg ' + type;
  statusMsg.innerHTML = type === 'loading'
    ? `<span class="loading-spinner"></span>${msg}`
    : msg;
}

function hideStatus() {
  statusSection.classList.add('hidden');
}

// 从 URL 提取 BV 号
function extractBVId(url) {
  if (!url) return null;
  const match = url.match(/BV[a-zA-Z0-9]{10}/);
  return match ? match[0] : null;
}

// 提取 aid（av 号）
function extractAvid(url) {
  const match = url.match(/av(\d+)/i);
  return match ? parseInt(match[1]) : null;
}

// 通过代理获取 JSON（自动尝试多个代理）
async function fetchJson(apiUrl) {
  let lastError = null;

  // 先用缓存的可用代理
  for (let i = 0; i < PROXIES.length; i++) {
    const idx = (workingProxyIdx + i) % PROXIES.length;
    const proxyUrl = PROXIES[idx](apiUrl);
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), 20000);
      const res = await fetch(proxyUrl, { signal: controller.signal });
      clearTimeout(timeoutId);
      if (!res.ok) {
        lastError = new Error(`HTTP ${res.status}`);
        continue;
      }
      const text = await res.text();
      try {
        const data = JSON.parse(text);
        workingProxyIdx = idx;  // 缓存可用代理
        return data;
      } catch (e) {
        lastError = new Error('响应不是有效 JSON');
        continue;
      }
    } catch (e) {
      lastError = e;
      continue;
    }
  }
  throw lastError || new Error('所有代理都失败');
}

// 通过代理获取二进制（用于下载）
async function fetchBlob(url) {
  // 下载二进制只能用本地代理或 allorigins（corsproxy 不支持二进制）
  const downloadProxies = [
    (u) => `/api/proxy?url=${encodeURIComponent(u)}`,
    (u) => `https://api.allorigins.win/raw?url=${encodeURIComponent(u)}`
  ];
  for (const proxy of downloadProxies) {
    try {
      const res = await fetch(proxy(url));
      if (!res.ok) continue;
      return await res.blob();
    } catch (e) {
      continue;
    }
  }
  throw new Error('下载失败：代理不可用');
}

// ============ B站 API 调用 ============

async function getVideoInfo(bvid) {
  const url = `${BILI_API.view}?bvid=${bvid}`;
  const data = await fetchJson(url);
  if (data.code !== 0) {
    throw new Error(`获取视频信息失败: ${data.message || '未知错误'} (code: ${data.code})`);
  }
  return data.data;
}

async function getPlayUrl(bvid, cid) {
  // fnval=16 DASH, qn=80 高清, fourk=1 允许4K
  const url = `${BILI_API.playurl}?bvid=${bvid}&cid=${cid}&qn=80&fnval=16&fnver=0&fourk=1`;
  const data = await fetchJson(url);
  if (data.code !== 0) {
    throw new Error(`获取播放地址失败: ${data.message || '未知错误'} (code: ${data.code})`);
  }
  return data.data;
}

// ============ 解析主流程 ============

async function parseVideo() {
  const input = urlInput.value.trim();
  if (!input) {
    showStatus('请输入B站视频网址', 'error');
    return;
  }

  const bvid = extractBVId(input);
  const avid = extractAvid(input);

  if (!bvid && !avid) {
    showStatus('未在输入中识别到 BV 号或 av 号', 'error');
    return;
  }

  parseBtn.disabled = true;
  resultSection.classList.add('hidden');
  showStatus(`正在解析 ${bvid || 'av' + avid} ...`);

  try {
    const info = await getVideoInfo(bvid);
    currentVideo = info;

    showStatus('正在获取播放地址...');
    const streams = await getPlayUrl(info.bvid, info.cid);
    currentStreams = streams;

    renderResult(info, streams);
    showStatus('✅ 解析成功！', 'success');
    setTimeout(() => hideStatus(), 2000);
  } catch (e) {
    showStatus(`❌ ${e.message}<br><br>提示：请确保已启动 <code>启动.bat</code>（本地代理服务器），公共代理可能不稳定。`, 'error');
  } finally {
    parseBtn.disabled = false;
  }
}

// ============ 渲染结果 ============

function renderResult(info, streams) {
  document.getElementById('videoCover').src = info.pic;
  document.getElementById('durationBadge').textContent = formatDuration(info.duration);
  document.getElementById('videoTitle').textContent = info.title;
  document.getElementById('videoAuthor').textContent = info.owner ? info.owner.name : '未知';
  document.getElementById('videoBvid').textContent = info.bvid;
  document.getElementById('videoViews').textContent = formatNumber(info.stat ? info.stat.view : 0);
  document.getElementById('videoLikes').textContent = formatNumber(info.stat ? info.stat.like : 0);
  document.getElementById('videoDate').textContent = formatDate(info.pubdate);
  document.getElementById('videoDesc').textContent = info.desc || '（无简介）';

  // 视频播放器（DASH 视频流，无声）
  const player = document.getElementById('videoPlayer');
  if (streams.dash && streams.dash.video && streams.dash.video.length > 0) {
    player.src = streams.dash.video[0].baseUrl || streams.dash.video[0].base_url;
  } else if (streams.durl && streams.durl.length > 0) {
    player.src = streams.durl[0].url;
  }

  renderStreams(streams);

  document.getElementById('downloadCoverBtn').onclick = () => downloadCover(info.pic, info.title);
  document.getElementById('copyUrlBtn').onclick = () => copyBestUrl(streams);
  document.getElementById('tryDownloadBtn').onclick = () => tryProxyDownload(streams, info.title);
  document.getElementById('openBiliBtn').onclick = () => {
    window.open(`https://www.bilibili.com/video/${info.bvid}`, '_blank');
  };

  resultSection.classList.remove('hidden');
}

function renderStreams(streams) {
  const list = document.getElementById('streamsList');
  list.innerHTML = '';

  if (streams.dash) {
    if (streams.dash.video) {
      streams.dash.video.forEach((v) => {
        list.appendChild(createStreamItem({
          quality: `${v.id}P`,
          type: 'video',
          codecs: v.codecs,
          bandwidth: v.bandwidth,
          url: v.baseUrl || v.base_url,
          size: v.size
        }));
      });
    }
    if (streams.dash.audio) {
      streams.dash.audio.forEach((a) => {
        const brMap = { 30216: '64K', 30232: '132K', 30280: '192K' };
        list.appendChild(createStreamItem({
          quality: `音频 ${brMap[a.id] || a.id + 'K'}`,
          type: 'audio',
          codecs: a.codecs,
          bandwidth: a.bandwidth,
          url: a.baseUrl || a.base_url,
          size: a.size
        }));
      });
    }
  }

  if (streams.durl && streams.durl.length > 0) {
    streams.durl.forEach((d, idx) => {
      list.appendChild(createStreamItem({
        quality: `分段 ${idx + 1}`,
        type: 'mp4/flv',
        codecs: '',
        bandwidth: 0,
        url: d.url,
        size: d.size
      }));
    });
  }

  if (list.children.length === 0) {
    list.innerHTML = '<div style="color:#8a8f99;font-size:13px;">未获取到可下载流</div>';
  }
}

function createStreamItem(stream) {
  const item = document.createElement('div');
  item.className = 'stream-item';

  const header = document.createElement('div');
  header.className = 'stream-header';
  header.innerHTML = `
    <span class="stream-quality">${stream.quality}</span>
    <span class="stream-type">${stream.type}</span>
  `;

  const codecs = document.createElement('div');
  codecs.className = 'stream-codecs';
  let codecText = stream.codecs || '';
  if (stream.bandwidth) codecText += ` · ${(stream.bandwidth / 1000).toFixed(0)} kbps`;
  if (stream.size) codecText += ` · ${(stream.size / 1024 / 1024).toFixed(2)} MB`;
  codecs.textContent = codecText;

  const urlBox = document.createElement('div');
  urlBox.className = 'stream-url';
  urlBox.textContent = stream.url;

  const actions = document.createElement('div');
  actions.className = 'stream-actions';

  const copyBtn = document.createElement('button');
  copyBtn.className = 'btn-secondary';
  copyBtn.textContent = '📋 复制';
  copyBtn.onclick = () => {
    navigator.clipboard.writeText(stream.url).then(() => {
      copyBtn.textContent = '✓ 已复制';
      setTimeout(() => copyBtn.textContent = '📋 复制', 1500);
    }).catch(() => {
      // 降级方案
      urlBox.select();
      document.execCommand('copy');
      copyBtn.textContent = '✓ 已复制';
      setTimeout(() => copyBtn.textContent = '📋 复制', 1500);
    });
  };

  const openBtn = document.createElement('button');
  openBtn.className = 'btn-secondary';
  openBtn.textContent = '🔗 打开';
  openBtn.onclick = () => window.open(stream.url, '_blank');

  const dlBtn = document.createElement('button');
  dlBtn.className = 'btn-secondary';
  dlBtn.textContent = '⬇️ 代理下载';
  dlBtn.onclick = () => downloadViaProxy(stream.url, stream.quality);

  actions.appendChild(copyBtn);
  actions.appendChild(openBtn);
  actions.appendChild(dlBtn);

  item.appendChild(header);
  item.appendChild(codecs);
  item.appendChild(urlBox);
  item.appendChild(actions);
  return item;
}

// ============ 下载功能 ============

async function downloadCover(url, title) {
  try {
    showStatus('正在下载封面...', 'loading');
    const blob = await fetchBlob(url);
    const ext = (url.match(/\.(png|jpg|jpeg|webp)/i) || [,'jpg'])[1];
    triggerBlobDownload(blob, `${sanitizeFileName(title)}_cover.${ext}`);
    showStatus('✅ 封面下载完成', 'success');
    setTimeout(() => hideStatus(), 2000);
  } catch (e) {
    window.open(url, '_blank');
    showStatus('封面代理下载失败，已打开封面网址，可右键另存为', 'error');
  }
}

async function downloadViaProxy(url, quality) {
  try {
    showStatus(`正在通过代理下载 ${quality}（可能较慢）...`, 'loading');
    const blob = await fetchBlob(url);
    const ext = url.includes('audio') ? 'm4a' : 'm4s';
    triggerBlobDownload(blob, `${sanitizeFileName(currentVideo.title)}_${quality}.${ext}`);
    showStatus('✅ 下载完成', 'success');
    setTimeout(() => hideStatus(), 2000);
  } catch (e) {
    showStatus(`❌ 下载失败: ${e.message}，请尝试复制链接用 IDM/yt-dlp 下载`, 'error');
  }
}

async function tryProxyDownload(streams, title) {
  let videoUrl = null;
  if (streams.dash && streams.dash.video && streams.dash.video.length > 0) {
    videoUrl = streams.dash.video[0].baseUrl || streams.dash.video[0].base_url;
  } else if (streams.durl && streams.durl.length > 0) {
    videoUrl = streams.durl[0].url;
  }

  if (!videoUrl) {
    showStatus('未找到可下载的视频流', 'error');
    return;
  }

  try {
    showStatus('正在通过代理下载视频流（可能较慢，请耐心等待）...', 'loading');
    const blob = await fetchBlob(videoUrl);
    triggerBlobDownload(blob, `${sanitizeFileName(title)}.m4s`);
    showStatus('✅ 视频流下载完成（DASH 格式，无声音）。如需完整视频，请同时下载音频流并用 ffmpeg 合并。', 'success');
  } catch (e) {
    showStatus(`❌ 下载失败: ${e.message}`, 'error');
  }
}

async function copyBestUrl(streams) {
  let url = '';
  if (streams.dash && streams.dash.video && streams.dash.video.length > 0) {
    url = streams.dash.video[0].baseUrl || streams.dash.video[0].base_url;
  } else if (streams.durl && streams.durl.length > 0) {
    url = streams.durl[0].url;
  }
  if (!url) {
    showStatus('未找到视频地址', 'error');
    return;
  }
  try {
    await navigator.clipboard.writeText(url);
    showStatus('✅ 视频地址已复制到剪贴板', 'success');
    setTimeout(() => hideStatus(), 2000);
  } catch (e) {
    showStatus('复制失败，请手动选择地址复制', 'error');
  }
}

function triggerBlobDownload(blob, filename) {
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

function sanitizeFileName(name) {
  return (name || 'video').replace(/[\\/:*?"<>|]/g, '_').slice(0, 80);
}

// ============ 事件绑定 ============

parseBtn.addEventListener('click', parseVideo);

urlInput.addEventListener('keypress', (e) => {
  if (e.key === 'Enter') parseVideo();
});

document.querySelectorAll('.example-link').forEach(btn => {
  btn.addEventListener('click', () => {
    urlInput.value = btn.dataset.url;
    parseVideo();
  });
});

// 启动时检测本地代理是否可用
async function checkLocalProxy() {
  try {
    const res = await fetch('/api/proxy?url=' + encodeURIComponent('https://api.bilibili.com/x/web-interface/view?bvid=BV1GJ411x7h7'));
    if (res.ok) {
      const data = await res.json();
      if (data && data.code === 0) {
        workingProxyIdx = 0;
        showStatus('✅ 本地代理可用，可以开始使用', 'success');
        setTimeout(() => hideStatus(), 2000);
        return;
      }
    }
  } catch (e) {
    console.log('Local proxy check failed:', e);
  }
  showStatus('⚠️ 未检测到本地代理。建议双击 <code>启动.bat</code> 启动本地代理服务器以获得稳定体验。当前将尝试公共代理（可能不稳定）。', 'error');
}

hideStatus();
checkLocalProxy();
