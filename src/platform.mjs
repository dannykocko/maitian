// 跨平台工具：macOS / Linux 的差异都收敛在这里，其他模块只调这里的函数，
// 不要在业务代码里直接写 osascript / sips / caffeinate / launchctl 这类系统调用。
import { spawn, execFileSync } from 'node:child_process';
import fs from 'node:fs'; import os from 'node:os'; import path from 'node:path';
import net from 'node:net';

export const isMac = process.platform === 'darwin';
export const isLinux = process.platform === 'linux';

const which = (name) => { try { return execFileSync('which', [name], { stdio: 'pipe' }).toString().trim() || null; } catch { return null; } };

// 找 Chrome / Chromium：优先环境变量，其次各系统常见位置。找不到返回 null（调用方给明确报错）
export function findChrome() {
  if (process.env.CHROME_BIN && fs.existsSync(process.env.CHROME_BIN)) return process.env.CHROME_BIN;
  if (isMac) {
    for (const p of [
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
      path.join(os.homedir(), 'Applications/Google Chrome.app/Contents/MacOS/Google Chrome'),
    ]) if (fs.existsSync(p)) return p;
    return null;
  }
  if (isLinux) {
    for (const name of ['google-chrome-stable', 'google-chrome', 'chromium', 'chromium-browser']) {
      const p = which(name); if (p) return p;
    }
    for (const p of ['/opt/google/chrome/chrome', '/usr/bin/google-chrome-stable', '/usr/bin/google-chrome', '/usr/bin/chromium', '/usr/bin/chromium-browser', '/snap/bin/chromium']) {
      if (fs.existsSync(p)) return p;
    }
  }
  return null;
}

// 缩略图工具：macOS 用自带 sips，其他系统用 ffmpeg；两个都没有返回 null（调用方退回原图，不崩）
let _thumb;
export function thumbTool() {
  if (_thumb !== undefined) return _thumb;
  if (isMac && fs.existsSync('/usr/bin/sips')) return (_thumb = 'sips');
  if (which('ffmpeg')) return (_thumb = 'ffmpeg');
  return (_thumb = null);
}

// 防休眠前缀：macOS 用 caffeinate，Linux 用 systemd-inhibit（没有就空数组，即不防休眠）
export function awakePrefix() {
  if (isMac) return ['caffeinate', '-dims'];
  if (isLinux && which('systemd-inhibit')) return ['systemd-inhibit', '--what=idle:sleep', '--why=maitian-publish'];
  return [];
}

// 带防休眠的 spawn：argv[0] 是要跑的程序（通常是 node），其余是参数
export function spawnAwake(argv, opts) {
  const prefix = awakePrefix();
  if (!prefix.length) return spawn(argv[0], argv.slice(1), opts);
  return spawn(prefix[0], [...prefix.slice(1), ...argv], opts);
}

// 本地端口是否有人在监听（替代 lsof/ss 这类系统命令，纯 Node 实现）
export function portListening(port, timeoutMs = 800) {
  return new Promise((res) => {
    const s = net.connect(port, '127.0.0.1');
    const done = (v) => { try { s.destroy(); } catch {} res(v); };
    s.once('connect', () => done(true));
    s.once('error', () => done(false));
    s.once('timeout', () => done(false));
    s.setTimeout(timeoutMs);
  });
}
