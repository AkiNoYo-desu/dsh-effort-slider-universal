# dsh-effort-slider-universal

**全模型推理滑条 / Universal reasoning-effort slider for DeepSeek Harness (DSH).**

把官方模型菜单里的「推理等级」那一行，改成一条可拖动的连续滑条 ——
而且**任何 provider、任何模型都会出现**，不再只有 DeepSeek 能拖。

> 基于 [Microqian2th/dsh-codex-effort-slider](https://github.com/Microqian2th/dsh-codex-effort-slider) 1.1.4（MIT）改造。
> 视觉、动画手感、设置面板全部沿用上游；本仓库只解决「换模型就消失」这一个问题。

---

## 为什么需要它（上游的一个真实缺口 / Why）

官方菜单的渲染是**有条件的**（`@deepseek-ai/dsh-client-ui-model-selection`）：

```jsx
pane === "root" && <>
  <button role="menuitem"> 模型 … </button>
  {reasoning !== void 0 && <button role="menuitem"> 推理等级 … </button>}   // 没有 reasoning 元数据就不画
</>
```

模型条目没有 `reasoning.efforts` 时，根面板**只有一行**。上游插件的定位逻辑是：

```js
if (items.length !== 2) return null;   // 恰好两个 menuitem 才动手，否则直接放弃
```

于是只有「目录里声明了档位」的模型能用：

| 当前模型 | 目录里的 `reasoning.efforts` | 根面板行数 | 上游 1.1.4 |
|---|---|---|---|
| DeepSeek 官方 | 有（off/low/high/max） | 2 | ✅ |
| kimi-k3.1-pro（订阅类 provider） | 常为空 | **1** | ❌ 整块消失 |
| glm / qwen / 其它未识别 provider | 常为空 | **1** | ❌ 整块消失 |

## 改了什么（Changes）

1. **没有官方那一行就自己补一行。** 根面板只剩模型行时，按官方结构造一个
   `role="menuitem"` 的行（同 class 形状、label + value 两个 span、不带 chevron ——
   它不导航到任何官方 pane）。关菜单 / 卸载时自己带走；重复扫描也不会插出第二行。
2. **没有官方档位就给合成档位。** 官方 `efforts` 优先；为空时按 provider 前缀给档位
   （deepseek / codex / claude / gemini / grok / kimi / glm / qwen … 兜底三档），
   模型名命中 `thinking|reasoning|o3|o4|gpt-5|opus|k2|k3|max` 时补一档 `max`。
   目录还没就绪（拿不到 provider/model）时**仍然不合成**，保留上游的 fail-open。
3. **写回先试、被拒说清楚、不刷屏。** 合成档位第一次拖动照样调官方
   `directory.select()`；被 `UNSUPPORTED_REASONING_EFFORT` 拒了就明示原因并记住这个模型，
   之后不再反复打宿主。用户还没选过时行内显示「默认」，不把显示锚点伪装成已生效。

**没有变的**：动画三档（快速 / 简洁 / 完整）、右键设置面板、诊断、颜色与粒子曲线、
`directory.select()` 这一个唯一写入口、以及「不改官方文字与 chevron」这条纪律。

## 装法（Install）

DSH Desktop：**设置 → 插件 → 添加插件**，填包名或仓库地址：

```
dsh-effort-slider-universal
github:OWNER/dsh-effort-slider-universal
```

装完**完全退出并重开** DSH Desktop（只关窗口不够，宿主在启动时把插件读进内存）。

> ⚠️ 如果你还装着上游 `dsh-codex-effort-slider`，请先卸载它再装这个：
> 两者都往同一行注入，同时存在会互相抢那一条滑条。

## 验证（Verify）

```bash
node test/client.test.mjs     # 470 项，全部通过
```

覆盖：只剩模型行 → 自建并注入；无档位 → 合成注入；`syntheticLevelsFor` 的 provider
推断；重复扫描幂等；写回被拒时给出可见提示且不重复写回。

## 边界（Honest limits）

- 合成档位保证的是**滑条无处不在、能拖、能读**。某个 provider 到底收不收
  `reasoningEffort`，取决于它自己的适配器；不收的话你会看到滑条下方那行提示，
  而不是请求被悄悄塞了无效参数搞成 400。
- 要让「真支持但目录没声明」的 provider 真生效，得让它适配器的 `resolveModel`
  返回 `reasoning.efforts`。那是第三方插件的事，本仓库不动它。

## License

MIT。原作品 © 2026 dsh-codex-effort-slider contributors（Microqian2th），
改造部分 © 2026 dsh-effort-slider-universal contributors。见 [LICENSE](LICENSE)。
