#!/bin/bash
# 麦田一行安装（跨平台 fork，支持 macOS 和 Linux）：
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/dannykocko/maitian/main/scripts/install.sh)"
# 做的事：检查 git 和 Node（≥22.5）→ 把麦田和麦田发布助手克隆到 ~/maitian/ → 运行安装向导
# 换目录：MAITIAN_HOME=~/somewhere bash -c "$(curl -fsSL …)"
# 换仓库：MAITIAN_REPO=你的用户名/maitian bash -c "$(curl -fsSL …)"
set -e
DIR=${MAITIAN_HOME:-$HOME/maitian}
REPO=${MAITIAN_REPO:-dannykocko/maitian}
PUBLISHER_REPO=${MAITIAN_PUBLISHER_REPO:-dannykocko/maitian-publisher}
OS=$(uname -s)
say() { echo; echo "== $1"; }

say "麦田 · 一行安装（装到 $DIR）"
if ! command -v git >/dev/null; then
  if [ "$OS" = "Darwin" ]; then echo "需要 git：先装 Xcode 命令行工具（xcode-select --install）";
  else echo "需要 git：Debian/Ubuntu 用 sudo apt install git；Fedora/RHEL 用 sudo dnf install git"; fi
  exit 1
fi
if ! command -v node >/dev/null; then
  if [ "$OS" = "Darwin" ]; then echo "需要 Node.js 22.5 以上：brew install node，或去 https://nodejs.org 下载";
  else echo "需要 Node.js 22.5 以上：去 https://nodejs.org 下载，或用 NodeSource 装 22.x（curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash - && sudo apt install -y nodejs）"; fi
  exit 1
fi
node -e 'const [a,b]=process.versions.node.split(".").map(Number);process.exit(a>22||(a===22&&b>=5)?0:1)' || { echo "Node.js 版本是 $(node -v)，需要 22.5 以上"; exit 1; }
if [ "$OS" = "Linux" ] && ! command -v ffmpeg >/dev/null; then echo "提示：没装 ffmpeg 的话网页缩略图会直接用原图；想开缩略图：sudo apt install ffmpeg"; fi
if ! command -v google-chrome-stable >/dev/null && ! command -v google-chrome >/dev/null && ! command -v chromium >/dev/null && ! command -v chromium-browser >/dev/null; then
  echo "提示：没找到 Chrome/Chromium；装好 Google Chrome 或 Chromium 才能登录各平台（也可以之后用 CHROME_BIN 指定路径）"
fi

mkdir -p "$DIR"; cd "$DIR"
clone_one() {   # $1 仓库（用户名/仓库名） $2 本地目录
  if [ -d "$2/.git" ]; then say "更新 $2"; git -C "$2" pull --ff-only -q; else say "下载 $2"; for i in 1 2 3; do git clone --depth 1 "https://github.com/$1.git" "$2" && break; echo "下载失败，第 $i 次重试"; rm -rf "$2"; sleep 3; done; [ -d "$2/.git" ] || { echo "$2 下载失败，检查网络后重跑这条命令"; exit 1; }; fi
}
clone_one "$REPO" maitian
clone_one "$PUBLISHER_REPO" mdldm-maitian-publisher

say "麦田发布助手（Chrome 插件）"
echo "Chrome 打开 chrome://extensions → 打开右上角「开发者模式」→「加载已解压的扩展程序」→ 选 $DIR/mdldm-maitian-publisher"
echo "（上架 Chrome 应用商店后也可以直接从商店安装）"

say "发布 skill"
L="$HOME/.claude/skills/maitian-publish"
if [ -e "$L" ] || [ -L "$L" ]; then echo "~/.claude/skills/maitian-publish 已经存在，没动它"
elif [ -d "$HOME/.claude/skills" ]; then ln -s "$DIR/maitian/skills/maitian-publish" "$L"; echo "已链接到 ~/.claude/skills/maitian-publish（Claude Code 里说「整理发布」就会用上）"
else echo "没找到 ~/.claude/skills；用 Claude Code 的话，把 $DIR/maitian/skills/maitian-publish 放进 ~/.claude/skills/"; fi

if [ "$OS" = "Linux" ] && [ -z "$DISPLAY" ]; then echo "提示：这台机器没有图形界面，首次登录各平台前请用 Xvfb 跑 Chrome（见 README 的「无头服务器」一节）"; fi

say "安装向导"
[ -t 0 ] || { echo "安装向导需要在终端里交互：cd $DIR/maitian && node src/init.mjs"; exit 0; }
cd "$DIR/maitian" && node src/init.mjs
