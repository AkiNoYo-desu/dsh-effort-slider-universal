#!/usr/bin/env bash
# 把插件提交到 awesome-dsh-plugin 收录列表（DSH 插件市场的数据源）。
#
# 规则（见 awesome-dsh-plugin/contributing.md）：
#   · 一个插件一个文件：data/plugins/<owner>__<repo>.yml
#   · package.json 必须声明 dsh.bundle（本仓库满足）
#   · 仓库要有 dsh-plugin topic（publish.sh 已加）
#   · 仓库创建满 1 天才会通过 CI —— 刚建的仓库今天提会被机器拦，明天再提即可
#
# 用法：./scripts/submit-market.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"
UPSTREAM="awesome-dsh-plugin/awesome-dsh-plugin"
REPO_NAME="dsh-effort-slider-universal"

command -v gh >/dev/null 2>&1 || { echo "[x] 没装 gh：brew install gh && gh auth login"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "[x] gh 未登录：gh auth login"; exit 1; }

OWNER="$(gh api user --jq .login)"
echo "[i] GitHub 账号：${OWNER}"

# ── 0. 前置检查 ─────────────────────────────────────────────────────────
if ! gh repo view "${OWNER}/${REPO_NAME}" >/dev/null 2>&1; then
  echo "[x] 还没建仓库 ${OWNER}/${REPO_NAME}，先跑 ./scripts/publish.sh"
  exit 1
fi
python3 -c 'import json,sys;d=json.load(open("package.json"));b=d.get("dsh",{}).get("bundle",{}).get("patch");sys.exit(0 if b else 1)' \
  || { echo "[x] package.json 没声明 dsh.bundle.patch，市场会拒收"; exit 1; }
CREATED="$(gh api "repos/${OWNER}/${REPO_NAME}" --jq .created_at)"
echo "[i] 仓库创建时间：${CREATED}（CI 要求满 24 小时）"

# ── 1. fork 上游列表仓库 ────────────────────────────────────────────────
gh repo fork "${UPSTREAM}" --clone=false >/dev/null 2>&1 || true
for _ in 1 2 3 4 5 6; do
  gh api "repos/${OWNER}/awesome-dsh-plugin" >/dev/null 2>&1 && break
  sleep 2
done
gh api "repos/${OWNER}/awesome-dsh-plugin" >/dev/null 2>&1 || { echo "[x] fork 还没就绪，稍后重跑本脚本"; exit 1; }

BASE_BRANCH="$(gh api "repos/${UPSTREAM}" --jq .default_branch)"
BASE_SHA="$(gh api "repos/${OWNER}/awesome-dsh-plugin/git/ref/heads/${BASE_BRANCH}" --jq .object.sha)"
BRANCH="add-${REPO_NAME}-$(date +%Y%m%d-%H%M%S)"
gh api --method POST "repos/${OWNER}/awesome-dsh-plugin/git/refs" \
  -f "ref=refs/heads/${BRANCH}" -f "sha=${BASE_SHA}" >/dev/null
echo "[i] fork 分支：${OWNER}:${BRANCH}"

# ── 2. 写条目文件（内容来自 submission/，替换 OWNER）────────────────────
ENTRY_PATH="data/plugins/${OWNER}__${REPO_NAME}.yml"
tmp="$(mktemp)"
sed "s/OWNER/${OWNER}/g" submission/template.yml > "${tmp}"
CONTENT_B64="$(base64 < "${tmp}" | tr -d '\n')"
rm -f "${tmp}"

gh api --method PUT "repos/${OWNER}/awesome-dsh-plugin/contents/${ENTRY_PATH}" \
  -f "message=Add ${OWNER}/${REPO_NAME}" \
  -f "content=${CONTENT_B64}" \
  -f "branch=${BRANCH}" >/dev/null
echo "[i] 已写入 ${ENTRY_PATH}"

# ── 3. 开 PR ────────────────────────────────────────────────────────────
BODY="$(cat <<EOF
Adds \`${OWNER}/${REPO_NAME}\`.

**What it does** — one draggable reasoning-effort slider in the DSH model menu. Unlike the upstream plugin it is a fork of, the slider also appears for providers and models whose catalog entry declares no \`reasoning.efforts\`: when the menu root has only the model row, the plugin adds an effort row itself and derives levels from the provider (deepseek/codex/claude/gemini/grok/kimi/glm/qwen/… with a three-level fallback). When a provider rejects an effort, the failure is shown in the row and is not retried for that model.

**Install**: \`dsh plugin --profile <profile> add ${REPO_NAME}\` (npm) or \`github:${OWNER}/${REPO_NAME}\`.

**Manifest**: \`package.json\` declares \`dsh.bundle.patch\` → \`./cordis.patch.yml\`, plus \`dsh.client.platform = web\`.

**Tests**: \`node test/client.test.mjs\` → 470 assertions passing.

**Upstream**: MIT fork of Microqian2th/dsh-codex-effort-slider 1.1.4; original copyright preserved in LICENSE.
EOF
)"
PR_URL="$(gh pr create --repo "${UPSTREAM}" --head "${OWNER}:${BRANCH}" --base "${BASE_BRANCH}" \
  --title "Add ${OWNER}/${REPO_NAME}" --body "${BODY}")"
echo "[ok] PR：${PR_URL}"
echo
echo "提醒：仓库创建满 24 小时后 CI 才会放行；如果被机器拦，明天重跑本脚本即可（会开新 PR）。"
