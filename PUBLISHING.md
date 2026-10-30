# 发布与上架（Publishing）

本仓库已经**备好可直接发布的状态**：代码、清单、图标、tarball、上架文案、脚本齐全。
剩下两步需要账号，脚本会自己做，不手改任何文件。

## 0. 一次性准备

```bash
brew install gh
gh auth login                 # 或 export GH_TOKEN=...
npm login                     # 上架 dshopen 需要 npm 包；也可用 npm token
```

## 1. 发布到 GitHub（+ npm + Release）

```bash
./scripts/publish.sh          # 加 --no-npm 可跳过 npm
```

它依次做：

1. 把 `package.json` / `README.md` / `submission/*` 里的 `OWNER` 换成你的 GitHub 用户名；
2. 跑一遍离线测试（470 项）；
3. `git init` → 提交；
4. `gh repo create <you>/dsh-effort-slider-universal --public --source=. --push`；
5. 加 topics：`dsh-plugin` / `dsh` / `deepseek-harness`；
6. `npm pack` → `dist/dsh-effort-slider-universal-2.0.0.tgz`；
7. 已登录 npm 就 `npm publish --access public`；
8. 打 tag `v2.0.0` + GitHub Release（附 tarball，市场会优先给这个预构建包）。

## 2. 申请上架 DSH 插件市场

你 profile 里配置的索引源是 **`https://dshopen.org/index.json`**（= `polang233/dsh-plugin-index`），
所以要上的是它：

```bash
./scripts/submit-market.sh dshopen
```

它开一条 issue（对应官方表单 `plugin-add.yml` 的字段），内容包含：npm 包名、仓库地址、
一句话说明、与上游插件的区别、许可证、manifest 说明、图标与测试结果。

> 该仓库的收录要求（README「提交插件」）：**公开源码 + 可安装的 npm 版本 + 明确许可证**。
> 没有 npm 版本时，issue 里说明固定 Git 提交也可能被接受，但优先 npm。
> 索引每 6 小时构建一次。

### 另一个市场（可选）

```bash
./scripts/submit-market.sh awesome
```

那是 `awesome-dsh-plugin/awesome-dsh-plugin`，一个插件一个 yml，走 PR（自动 fork → 建分支 → 写
`data/plugins/<owner>__dsh-effort-slider-universal.yml` → 开 PR）。

⚠️ 它有一条 CI 硬规则：**仓库创建满 24 小时**才放行。今天建仓、今天提会被机器拦，明天重跑即可。

## 3. 发布后自检

```bash
curl -s https://registry.npmjs.org/dsh-effort-slider-universal/latest | python3 -m json.tool | head
gh release view v2.0.0
```

再在 DSH 里「设置 → 插件 → 添加插件」填 `dsh-effort-slider-universal`，**完全退出重开**，
打开任意模型的菜单确认滑条出现。

## 没有账号时怎么办

发布是被**凭证**卡住的，不是被代码卡住的。缺 `gh`/npm 登录时脚本会明确报错并停下，
不会产生半成品仓库或脏提交。补齐登录后原样重跑即可（脚本幂等：已存在的仓库只推不重建）。
