// browser.mjs — 渲染进程、特效预览与截图/验收脚本共用的 Chromium 内核浏览器路径和 ANGLE 后端参数。
// EDGE_PATH 优先；否则按平台探测常见安装位置（Windows 默认 Edge；macOS / Linux 依次 Edge、Chrome、Chromium）。
import { existsSync } from 'node:fs';

const CANDIDATES = {
  win32: ['C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', 'C:/Program Files/Microsoft/Edge/Application/msedge.exe', 'C:/Program Files/Google/Chrome/Application/chrome.exe'],
  darwin: ['/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge', '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '/Applications/Chromium.app/Contents/MacOS/Chromium'],
  linux: ['/usr/bin/microsoft-edge', '/usr/bin/google-chrome', '/usr/bin/google-chrome-stable', '/usr/bin/chromium', '/usr/bin/chromium-browser'],
};

/** 浏览器可执行文件：EDGE_PATH > 本平台第一个存在的候选 > 本平台首个候选（找不到时报错信息里能看到期望路径）。 */
export function browserPath() {
  if (process.env.EDGE_PATH) return process.env.EDGE_PATH;
  const list = CANDIDATES[process.platform] ?? CANDIDATES.linux;
  return list.find((file) => existsSync(file)) ?? list[0];
}

/** WebGL 的 ANGLE 后端：Windows 用 D3D11；macOS 用 Metal（macOS 上 d3d11 不可用，会退回 SwiftShader 软件渲染）；其他平台用浏览器默认。 */
export function angleArgs() {
  if (process.platform === 'win32') return ['--use-angle=d3d11'];
  if (process.platform === 'darwin') return ['--use-angle=metal'];
  return [];
}
