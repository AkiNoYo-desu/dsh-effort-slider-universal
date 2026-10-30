#!/usr/bin/env bash
# 发布 dsh-effort-slider-universal 到 GitHub（建仓库 → 推代码 → 打标签 → 出 Release → 可选发 npm）。
#
# 前置：gh 已登录（`gh auth login`），或设置 GITHUB_TOKEN。
# 可选：`npm login` 之后脚本会顺带发布 npm 包（未登录则跳过）。
#
# 用法：./scripts/publish.sh [--no-npm]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"
REPO_NAME="dsh-effort-slider-universal"
VERSION="$("${PYTHON:-python3}" -c 'import json,sys;print(json.load(open("package.json"))["version"])')"

DO_NPM=1
[ "${1:-}" = "--no-npm" ] && DO_NPM=0

# gh 可能在 ~/.local/bin（本机没有 brew 时手动装的）
GH_BIN="$(command -v gh || true)"
[ -z "${GH_BIN}" ] && [ -x "${HOME}/.local/bin/gh" ] && GH_BIN="${HOME}/.local/bin/gh"
[ -n "${GH_BIN}" ] || { echo "[x] 没装 gh：brew install gh，或把 gh 放到 ~/.local/bin"; exit 1; }
"${GH_BIN}" auth status >/dev/null 2>&1 || { echo "[x] gh 未登录：${GH_BIN} auth login"; exit 1; }
GH() { "${GH_BIN}" "$@"; }

OWNER="$("${GH_BIN}" api user --jq .login)"
echo "[i] GitHub 账号：${OWNER}"

# ── 1. OWNER 占位替换（幂等）─────────────────────────────────────────────
python3 - "${OWNER}" <<'PY'
import json, pathlib, sys
owner = sys.argv[1]
files = [pathlib.Path("package.json"), pathlib.Path("README.md"),
         pathlib.Path("submission/template.yml"), pathlib.Path("submission/README.md")]
for f in files:
    if not f.exists():
        continue
    s = f.read_text(encoding="utf-8")
    if "OWNER" not in s:
        continue
    f.write_text(s.replace("OWNER", owner), encoding="utf-8")
    print(f"[i] 已把 OWNER 换成 {owner}：{f}")
PY

# ── 2. 测试 ──────────────────────────────────────────────────────────────
NODE_BIN="${NODE_BIN:-$(command -v node || true)}"
if [ -z "${NODE_BIN}" ]; then
  for c in "${HOME}/.dsh/mcp/rea"/node-runtime/*/bin/node; do [ -x "${c}" ] && NODE_BIN="${c}" && break; done
fi
if [ -n "${NODE_BIN}" ]; then
  echo "[..] 离线测试"
  "${NODE_BIN}" test/client.test.mjs | tail -2
else
  echo "[!] 没找到 node，跳过测试"
fi

# ── 3. git 提交 ─────────────────────────────────────────────────────────
if [ ! -d .git ]; then
  git init -q
  git symbolic-ref HEAD refs/heads/main
  echo "[i] git init（默认分支 main）"
fi
git add -A
if ! git diff --cached --quiet; then
  git -c user.name="${OWNER}" -c user.email="${OWNER}@users.noreply.github.com" \
      commit -q -m "dsh-effort-slider-universal ${VERSION}: effort slider for every provider and model"
  echo "[i] 已提交"
fi

# ── 4. 建仓库并推送 ─────────────────────────────────────────────────────
DESC="Universal reasoning-effort slider for DeepSeek Harness: the model menu's effort row becomes one draggable slider that shows up for every provider and model."
if "${GH_BIN}" repo view "${OWNER}/${REPO_NAME}" >/dev/null 2>&1; then
  echo "[i] 仓库已存在，直接推送"
  git remote get-url origin >/dev/null 2>&1 || git remote add origin "https://github.com/${OWNER}/${REPO_NAME}.git"
  git push -u origin main
else
  "${GH_BIN}" repo create "${OWNER}/${REPO_NAME}" --public --description "${DESC}" --source=. --remote=origin --push
fi
"${GH_BIN}" repo edit "${OWNER}/${REPO_NAME}" --add-topic dsh-plugin --add-topic dsh --add-topic deepseek-harness >/dev/null
echo "[i] 已加 topics: dsh-plugin / dsh / deepseek-harness"

# ── 5. npm 包（Release 附件 + 可选 registry）─────────────────────────────
mkdir -p dist
TGZ="dist/${REPO_NAME}-${VERSION}.tgz"
if [ -n "${NPM_BIN:-$(command -v npm || true)}" ]; then
  "${NPM_BIN:-npm}" pack --pack-destination dist >/dev/null
  echo "[i] 打包：${TGZ}"
elif [ -f "${TGZ}" ]; then
  echo "[i] 沿用已生成的 tarball：${TGZ}"
else
  echo "[!] 没有 npm 也没有现成 tarball，Release 将不带附件"
  TGZ=""
fi

NPM_BIN="${NPM_BIN:-$(command -v npm || true)}"
if [ -z "${NPM_BIN}" ]; then
  for c in "${HOME}"/.dsh/mcp/rea/node-runtime/*/bin/npm "${HOME}"/.dsh/dsh-runtimes/*/dependencies/node/bin/npm; do
    [ -x "${c}" ] && NPM_BIN="${c}" && break
  done
fi
if [ "${DO_NPM}" -eq 1 ] && [ -n "${NPM_BIN}" ] && "${NPM_BIN}" whoami >/dev/null 2>&1; then
  echo "[..] npm publish"
  "${NPM_BIN}" publish --access public || echo "[!] npm 发布失败（可稍后手动 npm publish）"
else
  echo "[i] 跳过 npm（未登录或已指定 --no-npm）"
fi

# ── 6. tag + Release ────────────────────────────────────────────────────
git tag -f "v${VERSION}" >/dev/null
git push -f origin "v${VERSION}" >/dev/null
if [ -n "${TGZ}" ] && [ -f "${TGZ}" ]; then
  "${GH_BIN}" release create "v${VERSION}" "${TGZ}" --title "v${VERSION}" \
     --notes "全模型推理滑条：官方没声明推理档位的 provider/模型也会出现滑条（自建行 + 合成档位）。基于 dsh-codex-effort-slider 1.1.4（MIT）改造。详见 README。" \
     || "${GH_BIN}" release upload "v${VERSION}" "${TGZ}" --clobber
else
  "${GH_BIN}" release create "v${VERSION}" --title "v${VERSION}" --notes "见 README" || true
fi

echo
echo "[ok] 仓库：https://github.com/${OWNER}/${REPO_NAME}"
echo "     Release：https://github.com/${OWNER}/${REPO_NAME}/releases/tag/v${VERSION}"
echo "     下一步：./scripts/submit-market.sh   （提交到 awesome-dsh-plugin 收录列表）"
