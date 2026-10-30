#!/usr/bin/env bash
# 申请上架。支持两个目标：
#   ./scripts/submit-market.sh dshopen    # 开放插件市场（dshopen.org / polang233/dsh-plugin-index）—— DSH 里配的那个索引源
#   ./scripts/submit-market.sh awesome    # awesome-dsh-plugin 精选列表（市场应用 dshmarket 的数据源）
#
# 前置：gh 已登录；dshopen 要求**已发布 npm 包**（或在 issue 里说明固定 Git 提交）。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"
TARGET="${1:-dshopen}"
REPO_NAME="dsh-effort-slider-universal"

command -v gh >/dev/null 2>&1 || { echo "[x] 没装 gh：brew install gh && gh auth login"; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "[x] gh 未登录：gh auth login"; exit 1; }
OWNER="$(gh api user --jq .login)"
VERSION="$(python3 -c 'import json;print(json.load(open("package.json"))["version"])')"

if ! gh repo view "${OWNER}/${REPO_NAME}" >/dev/null 2>&1; then
  echo "[x] 还没建仓库 ${OWNER}/${REPO_NAME}，先跑 ./scripts/publish.sh"
  exit 1
fi

NPM_STATUS="未发布到 npm（仅 GitHub）"
if curl -sf --max-time 15 "https://registry.npmjs.org/${REPO_NAME}/${VERSION}" >/dev/null 2>&1; then
  NPM_STATUS="npm \`${REPO_NAME}@${VERSION}\`"
fi

case "${TARGET}" in
  dshopen)
    # ── 开放插件市场：issue 表单式收录 ──────────────────────────────────
    BODY="$(cat <<EOF
### 插件地址 / Plugin link
\`${REPO_NAME}\` — https://github.com/${OWNER}/${REPO_NAME}

### 简短说明 / Summary
把 DSH 模型菜单里的「推理等级」换成一条可拖动的连续滑条，**任何 provider、任何模型都会出现**：官方没声明 \`reasoning.efforts\` 时插件自己补一行推理等级行，并按 provider 前缀合成档位（deepseek/codex/claude/gemini/grok/kimi/glm/qwen … 兜底三档）。写回仍走官方 \`directory.select()\`；provider 拒绝时在行内明示、且不重复重试，不会把无效参数硬塞给上游。

### 补充信息 / Additional details
- 安装：\`npm i -g ${REPO_NAME}\` 或 DSH 插件面板填 \`${REPO_NAME}\` / \`github:${OWNER}/${REPO_NAME}\`
- 版本：${VERSION}（npm：${NPM_STATUS}）
- 许可证：MIT（fork 自 \`dsh-codex-effort-slider\` 1.1.4，原版权保留在 LICENSE）
- 清单：\`package.json\` 声明 \`dsh.bundle.patch\` → \`./cordis.patch.yml\`，\`dsh.client.platform = web\`
- Logo：https://raw.githubusercontent.com/${OWNER}/${REPO_NAME}/main/assets/icon-180.png
- 测试：\`node test/client.test.mjs\` → 470 项断言通过
- 与上游的区别（避免与已有条目重复）：上游只在目录声明了档位的模型上出现滑条；本包在未声明档位时自建行 + 合成档位，并明确提示 provider 拒绝
EOF
)"
    URL="$(gh issue create --repo polang233/dsh-plugin-index \
      --title "[plugin-add] ${REPO_NAME}" --body "${BODY}")"
    echo "[ok] 上架申请：${URL}"
    echo "     索引每 6 小时构建一次；审核通过后 dshopen.org 与 DSH 的「发现」里就能搜到。"
    ;;

  awesome)
    # ── awesome-dsh-plugin：一个 yml 一个 PR ────────────────────────────
    UPSTREAM="awesome-dsh-plugin/awesome-dsh-plugin"
    python3 -c 'import json,sys;d=json.load(open("package.json"));sys.exit(0 if d.get("dsh",{}).get("bundle",{}).get("patch") else 1)' \
      || { echo "[x] package.json 没声明 dsh.bundle.patch，会被拒"; exit 1; }
    CREATED="$(gh api "repos/${OWNER}/${REPO_NAME}" --jq .created_at)"
    echo "[i] 仓库创建时间 ${CREATED}（CI 要求满 24 小时，未满会拦）"

    gh repo fork "${UPSTREAM}" --clone=false >/dev/null 2>&1 || true
    for _ in 1 2 3 4 5 6; do gh api "repos/${OWNER}/awesome-dsh-plugin" >/dev/null 2>&1 && break; sleep 2; done
    gh api "repos/${OWNER}/awesome-dsh-plugin" >/dev/null 2>&1 || { echo "[x] fork 未就绪，稍后重跑"; exit 1; }

    BASE_BRANCH="$(gh api "repos/${UPSTREAM}" --jq .default_branch)"
    BASE_SHA="$(gh api "repos/${OWNER}/awesome-dsh-plugin/git/ref/heads/${BASE_BRANCH}" --jq .object.sha)"
    BRANCH="add-${REPO_NAME}-$(date +%Y%m%d-%H%M%S)"
    gh api --method POST "repos/${OWNER}/awesome-dsh-plugin/git/refs" \
      -f "ref=refs/heads/${BRANCH}" -f "sha=${BASE_SHA}" >/dev/null

    ENTRY_PATH="data/plugins/${OWNER}__${REPO_NAME}.yml"
    tmp="$(mktemp)"
    sed "s/OWNER/${OWNER}/g" submission/template.yml > "${tmp}"
    CONTENT_B64="$(base64 < "${tmp}" | tr -d '\n')"
    rm -f "${tmp}"
    gh api --method PUT "repos/${OWNER}/awesome-dsh-plugin/contents/${ENTRY_PATH}" \
      -f "message=Add ${OWNER}/${REPO_NAME}" -f "content=${CONTENT_B64}" -f "branch=${BRANCH}" >/dev/null
    echo "[i] 已写入 ${ENTRY_PATH}"

    PR_BODY="$(cat <<EOF
Adds \`${OWNER}/${REPO_NAME}\`.

**What it does** — one draggable reasoning-effort slider in the DSH model menu. Unlike the upstream plugin this forks, the slider also appears for providers and models whose catalog entry declares no \`reasoning.efforts\`: when the menu root renders only the model row, the plugin adds an effort row itself and derives levels from the provider (deepseek/codex/claude/gemini/grok/kimi/glm/qwen/… with a three-level fallback). Write-through still uses the official \`directory.select()\`; a rejected effort is surfaced in the row and not retried for that model.

**Install**: \`github:${OWNER}/${REPO_NAME}\` (source) — ${NPM_STATUS}.

**Manifest**: \`package.json\` declares \`dsh.bundle.patch\` → \`./cordis.patch.yml\`, plus \`dsh.client.platform = web\`.

**Tests**: \`node test/client.test.mjs\` → 470 assertions passing.

**Upstream**: MIT fork of Microqian2th/dsh-codex-effort-slider 1.1.4; original copyright preserved in LICENSE.
EOF
)"
    PR_URL="$(gh pr create --repo "${UPSTREAM}" --head "${OWNER}:${BRANCH}" --base "${BASE_BRANCH}" \
      --title "Add ${OWNER}/${REPO_NAME}" --body "${PR_BODY}")"
    echo "[ok] PR：${PR_URL}"
    ;;

  *)
    echo "用法：$0 [dshopen|awesome]"
    exit 1
    ;;
esac
