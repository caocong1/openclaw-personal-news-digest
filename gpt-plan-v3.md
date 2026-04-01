# OpenClaw 个性化新闻系统计划文档

> **v3 变更摘要**：基于 6 个 AI 模型对 v2 的独立评审，进行系统性优化。主要变更：
>
> 1. **新增 LLM 成本预算与熔断机制**（§4.3）— 6/6 评审一致要求
> 2. **新增上下文窗口管理策略**（§4.4）— 解决流水线上下文压力
> 3. **新增 LLM 结果缓存层**（§4.5）— 降低重复调用成本
> 4. **新增监控与可观测性**（§4.6）— 5/6 评审要求
> 5. **新增多语言处理策略**（§7.4）— 5/6 评审指出缺失
> 6. **新增来源健康度动态评估**（§7.5）— 替代静态 credibility
> 7. **SKILL.md 拆分为模块化结构**（§3.1.1）— 避免巨型单文件
> 8. **新增核心 LLM Prompt 模板**（§8.3, §11.1）— 填补决策点空白
> 9. **精简数据模型**：移除 `full_content`/`media_urls`/`word_count`，收缩 `form_type` 枚举，时间线关系类型 9→5
> 10. **精简反馈系统**：MVP 阶段取消全量重建和撤销协议，简化偏好衰减
> 11. **精简运行保障**：锁机制收缩为"获取失败即跳过"，移除细粒度 heartbeat
> 12. **合并 Phase 0** 三子阶段为单一阶段，加快起步节奏
> 13. **新增输出解释字段**（§13.3）— 提升用户信任与反馈质量
> 14. **新增隐私与合规基础约定**（§15.3）
>
> 详见各章节内的 `[v3]` 标记。

---

# 第一部分：基础定义

---

## 1. 项目定位与目标

本文档定义一个基于 OpenClaw 的个性化新闻研究与推送 Skill 的完整设计规格。

### 1.1 核心目标

1. 能长期、稳定地收集新闻与动态信息
2. 能根据用户兴趣进行深度个性化
3. 能避免系统逐渐收缩成单一兴趣茧房
4. 能处理重复新闻、转载新闻、后续更新新闻
5. 能把连续发展的新闻串成"事件时间线"
6. 能支持多主题，而不仅限于 AI / 开发 / 科技
7. 能从"给你推消息"逐步升级为"替你持续观察世界中你关心的部分"

### 1.2 项目性质

本项目是一个 **OpenClaw Skill**，不是独立的后端服务或应用。它运行在 OpenClaw Agent 内部，利用平台原生的工具链（采集、调度、推送、存储）来完成新闻编排任务。

---

## 2. 项目边界与形态决策

### 2.1 第一原则

这个系统不是简单的"RSS 搬运器"或"热搜转发器"，而是一个有主题意识、有偏好记忆、有去重能力、有事件归并能力、有时间线能力、有探索与纠偏能力的新闻编排 Skill。

### 2.2 形态决策

项目主体定为一个 OpenClaw Skill，包含：

- 一个 `SKILL.md` 作为编排指令中心
- 一组引用文档（references/）作为详细规范
- 一组辅助脚本（scripts/）处理数据一致性逻辑
- 一组工作空间文件作为数据与配置存储
- 利用 OpenClaw 原生工具完成采集、调度、推送

### 2.3 Skill 与平台的职责边界

| 职责 | 负责方 | 说明 |
|------|--------|------|
| 内容处理逻辑 | **Skill** | 分类、去重、归并、评分、摘要生成 |
| 偏好管理 | **Skill** | 偏好模型的存储与更新 |
| 事件跟踪 | **Skill** | 事件归并、时间线维护、生命周期管理 |
| 输出生成 | **Skill** | 日报/快讯/周报等内容的格式化输出 |
| 来源采集触发 | **OpenClaw cron** | 定时触发 agent 执行采集任务 |
| 推送渠道 | **OpenClaw message/delivery** | Telegram/Discord/Slack 等渠道投递 |
| 调度管理 | **OpenClaw cron** | cron 表达式、频率、时区等 |
| 用户交互通道 | **OpenClaw 平台** | 用户通过聊天通道与 agent 交互 |

---

## 3. OpenClaw 平台集成设计

### 3.1 SKILL.md 规格

```yaml
---
name: news-digest
description: 个性化新闻研究与推送系统。收集多来源新闻，基于多维偏好模型进行个性化编排，支持事件归并、时间线跟踪和防茧房机制。
user-invocable: true
metadata: {"openclaw":{"always":true}}
---
```

#### 3.1.1 模块化文档结构 [v3 重写]

**设计原则**：SKILL.md 只承载高层编排逻辑，详细规范拆分到 references/ 目录。这样做的原因是：
- 避免 SKILL.md 膨胀成巨型指令文件，降低 agent 执行一致性（6/6 评审共识）
- 减轻单次 agent turn 的上下文窗口压力
- 便于独立调优各模块

```text
<skill-workspace>/
├── SKILL.md                          # 高层编排：角色定义 + 流程步骤 + 条件路由
├── references/
│   ├── data-models.md                # 数据模型 JSON Schema
│   ├── prompts/
│   │   ├── classify.md               # 分类 prompt 模板
│   │   ├── summarize.md              # 摘要 prompt 模板
│   │   ├── dedup.md                  # 去重判断 prompt 模板
│   │   └── merge-event.md            # 事件归并 prompt 模板
│   ├── output-templates.md           # 日报/快讯/周报输出模板
│   ├── feedback-rules.md             # 反馈类型映射与偏好更新规则
│   └── scoring-formula.md            # 评分公式与配额算法
├── scripts/
│   ├── dedup-index-rebuild.sh        # dedup-index 重建
│   ├── data-archive.sh               # 过期数据归档清理
│   └── health-check.sh               # 数据一致性巡检
├── config/
├── data/
└── output/
```

**SKILL.md 正文结构**（精简为 6 个核心部分）：

1. **角色定义** — 你是什么、运行环境、工作空间布局
2. **采集指令** — 按来源类型的采集步骤，引用 `references/prompts/`
3. **处理指令** — 分类→去重→归并→评分→配额的步骤流程
4. **输出指令** — 日报/快讯/周报的触发条件和生成流程，引用 `references/output-templates.md`
5. **反馈指令** — 反馈识别和偏好更新，引用 `references/feedback-rules.md`
6. **运行约束** — Standing Orders、成本限制、降级条件

每部分包含明确的步骤编号和条件判断，使 agent 按指令直接执行。详细 prompt 模板和数据格式通过 `read` 工具按需加载，不全量塞入上下文。

### 3.2 可用工具映射

| Skill 功能 | OpenClaw 工具 | 用途 |
|-----------|-------------|------|
| RSS/API 采集 | `web_fetch` | 获取 RSS XML、GitHub API 等结构化数据 |
| 网页抓取 | `browser` | 抓取需要渲染的网页内容（热门榜单、社区页面） |
| 搜索类来源 | `web_search` | 基于关键词搜索最新新闻 |
| 数据读写 | `read` / `write` | 读写工作空间内的 JSON/JSONL 数据文件 |
| 调度触发 | `cron` | 通过 cron job 的 agentTurn payload 触发采集/生成任务 |
| 内容推送 | `message` + cron `delivery` | 通过 cron job 的 delivery 配置将输出发送到聊天渠道 |
| 偏好记忆 | 工作空间文件 | 持久化偏好数据到 `config/preferences.json` |
| 辅助脚本 | `exec` | 执行数据清理、索引重建等确定性脚本（需验证平台支持） |

**平台能力待验证清单** [v3 新增]：

以下假设需在 Phase 0 验证，影响后续设计决策：

| 假设 | 验证方式 | 失败时降级方案 |
|------|---------|---------------|
| isolated session 可访问工作空间文件 | Phase 0 实际测试 | 改用 shared session |
| `exec` 可执行辅助脚本 | Phase 0 权限测试 | 将脚本逻辑写入 SKILL.md 指令 |
| `browser` 工具可稳定抓取渲染页面 | Phase 1 来源扩展时测试 | 降级为纯 `web_fetch` + 静态解析 |
| cron `delivery` 支持多渠道投递 | Phase 0 配置测试 | 改为 agent 主动调用 `message` |
| 单次 agent turn 超时 ≥ 10 分钟 | Phase 0 压力测试 | 拆分为多个 cron 子任务 |

### 3.3 Cron Job 配置参考

以下为通用模板，用户按需调整参数：

```json
{
  "name": "{任务名称}",
  "schedule": { "kind": "cron", "expr": "{cron 表达式}", "tz": "Asia/Shanghai" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "{任务指令}",
    "lightContext": false
  },
  "delivery": {
    "mode": "announce",
    "channel": "{渠道}",
    "to": "{目标 ID}"
  }
}
```

**推荐任务配置**：

| 任务 | cron 表达式 | lightContext | 说明 |
|------|-----------|-------------|------|
| 日报 | `0 8 * * *` | false | 每天早 8 点，完整上下文 |
| 快讯检查 | `0 */2 * * *` | true | 每 2 小时，轻量上下文，无内容不输出 |
| 周报 | `0 20 * * 0` | false | 每周日晚 8 点，可选 opus 模型 |
| 健康巡检 | `0 3 * * 1` | true | 每周一凌晨，数据一致性检查 [v3 新增] |

### 3.4 Standing Orders 设计

```markdown
## 新闻系统 Standing Orders

### 授权范围
- 按 cron 触发自动执行新闻采集和输出生成
- 自动更新事件状态和时间线
- 自动执行去重和归并
- 根据用户反馈自动调整偏好权重

### 升级条件（需要人工确认）
- 删除来源配置
- 大幅调整偏好权重（单次变化 > 0.3）
- 归档仍在跟踪中的事件
- 单日 LLM 调用次数接近预算上限（> 80%）[v3 新增]

### 禁止事项
- 不得自行添加未经用户确认的来源
- 不得将偏好数据发送到外部服务
- 不得在无新内容时强制生成空输出
- 不得超出 LLM 日预算上限执行非必要调用 [v3 新增]
```

---

## 4. 顶层架构

```text
主 Skill（编排中心 — SKILL.md）
├─ 来源层（按来源类型分组）            → web_fetch / browser / web_search
├─ 缓存层（LLM 结果缓存）             → data/cache/ [v3 新增]
├─ 分类层（多标签主题分类）            → LLM 分类（引用 prompts/classify.md）
├─ 偏好层（5 层兴趣模型 [v3 收缩]）    → config/preferences.json
├─ 去重归并层（新闻项 → 事件）         → LLM 判断 + URL 索引
├─ 时间线层（事件生命周期跟踪）        → data/events/
├─ 输出层（日报/快讯/周报格式生成）    → LLM 生成 + 模板
├─ 反馈学习层（用户修正 → 偏好更新）  → data/feedback/ → config/preferences.json
├─ 防茧房层（配额约束，贯穿全流程）    → 配额算法
└─ 监控层（健康度指标采集）            → data/metrics/ [v3 新增]
```

处理流水线：

```text
来源采集 → 缓存查询 → 链接去重 → LLM 分类/摘要 → 标题去重
    → 事件归并 → 偏好评分 → 防茧房配额 → 输出格式化 → 推送
```

### 4.1 运行保障规则 [v3 精简]

#### 4.1.1 单实例互斥（简化锁）

采用文件锁作为互斥原语，策略为 **"获取失败即跳过"**：

1. 尝试创建 `data/.lock`，写入 `{ "run_id": "run-YYYYMMDD-HHmmss-random4", "started_at": "ISO8601" }`
2. 创建成功 → 获取锁，继续执行
3. 创建失败（文件已存在）→ 检查 `started_at`：
   - 距今 < 15 分钟 → 锁有效，**跳过本次执行**
   - 距今 ≥ 15 分钟 → 锁过期（stale），删除后重新创建
4. 任务完成 → 删除 `data/.lock`

> v3 变更说明：移除 heartbeat、mkdir 原子性依赖、多种 stale case 分支处理。单用户、低并发场景下"获取失败即跳过"已足够（4/6 评审建议）。

#### 4.1.2 Run ID 与原子写入

- 每次运行分配唯一 `run_id`（格式：`run-YYYYMMDD-HHmmss-random4`）
- 所有数据写入先写临时文件 `*.tmp.{run_id}`，完成后 rename
- 崩溃恢复：启动时扫描 `data/**/*.tmp.*`，创建 > 15 分钟的 → 删除

#### 4.1.3 幂等与断点续跑

- **完全重复**：`normalized_url` SHA 已在 dedup-index → 跳过不落盘
- **近似重复**：标题近似去重识别 → 落盘但标记 `dedup_status: "title_dup"`
- **断点续跑**：`processing_status: "raw"` 的记录，下次运行补充分类/摘要

#### 4.1.4 超时与降级

- 单次采集任务硬超时：5 分钟
- 来源按权重降序采集，超时时低优先来源被跳过
- 连续 3 次失败：采集间隔 ×2；连续 7 次：标记 `source.status: "degraded"`

### 4.2 容错规则

| 故障场景 | 处理方式 |
|---------|---------|
| 来源采集失败 | 记录 `last_error` + `consecutive_failures`，连续 7 次标记 degraded |
| LLM 调用失败 | 跳过分类/摘要，标记 `processing_status: "partial"`，日报中仅显示标题+来源 |
| LLM 返回格式异常 | 重试 1 次；仍失败则标记 partial |
| RSS 非标准 XML | 宽松解析，提取可用字段 |
| 分类失败但摘要成功 | 允许进入日报，标记"未分类"，归入探索位 [v3 新增] |
| 一天仅有低质量内容 | 日报缩短输出而非硬凑条数 [v3 新增] |
| 快讯误触发 | 不发送；快讯阈值偏保守，宁缺毋滥 [v3 新增] |

### 4.3 LLM 成本预算与熔断 [v3 新增]

> 6/6 评审一致指出 LLM 成本未做预算是最大隐患。以下为各阶段估算。

#### 日均 LLM 调用估算

| 环节 | Phase 0-1 调用量 | Phase 2-3 调用量 | 说明 |
|------|----------------|----------------|------|
| 分类 | 50-100 次 | 200-500 次（可批量，5条/次） | 每条新闻 1 次 |
| 摘要 | 50-100 次 | 200-500 次 | 去重后剩余条数 |
| 标题去重 | 0 | 5-15 次 | 仅候选组，批量处理 |
| 事件归并 | 0 | 10-30 次 | 每日新增事件 × 候选匹配 |
| 日报生成 | 1 次 | 1 次 | 编排+格式化 |
| 快讯判断 | 0-12 次 | 0-12 次 | 每 2h 一次，大多无输出 |
| **日均合计** | **~100-200** | **~400-1000** | — |

#### Token 成本估算（以 Sonnet 级模型为参考）

| 阶段 | 日均 token 消耗 | 月成本估算 |
|------|---------------|-----------|
| Phase 0-1 | ~200K input + 50K output | < $5/月 |
| Phase 2-3 | ~800K input + 200K output | < $20/月 |

#### 成本控制策略

1. **批量处理**：分类和摘要尽可能批量（5-10 条/次），减少 per-call overhead
2. **缓存复用**：同 URL 的分类/摘要结果缓存 7 天（§4.5）
3. **分级模型**：简单任务（分类）用快速模型，复杂任务（归并判断、周报）用强模型
4. **日预算上限**：设置 `config/budget.json` 的 `daily_llm_call_limit`（默认 500）
5. **熔断机制**：超过日预算 80% 时告警，100% 时停止非必要 LLM 调用（仅保留日报生成）

```jsonc
// config/budget.json
{
  "daily_llm_call_limit": 500,
  "daily_token_limit": 1000000,  // 1M tokens
  "alert_threshold": 0.8,
  "current_date": "YYYY-MM-DD",
  "calls_today": 0,
  "tokens_today": 0
}
```

### 4.4 上下文窗口管理 [v3 新增]

> Claude Opus 4.6 评审指出流水线上下文压力是工程隐患。

**核心策略：分步执行 + 按需加载**

一个完整的日报生成不在单次 agent turn 中完成全部步骤，而是：

1. **采集阶段**：SKILL.md 核心指令 + 来源配置 → 采集结果写入 JSONL
2. **处理阶段**：读取当日 JSONL + `references/prompts/classify.md` → 分类/摘要结果写回
3. **评分+输出阶段**：读取已处理数据 + `references/scoring-formula.md` + `references/output-templates.md` → 生成日报

每个阶段只加载该阶段需要的引用文档，避免一次性加载全部规范。

**SKILL.md 体积控制**：目标 < 3000 tokens（约 2000 字中文），只包含流程骨架和条件路由。

### 4.5 LLM 结果缓存层 [v3 新增]

> 5/6 评审建议增加缓存，减少对相同/相似内容的重复 LLM 调用。

```text
data/cache/
├── classify-cache.json    # URL SHA → { categories, cached_at }
└── summary-cache.json     # URL SHA → { summary, cached_at }
```

**缓存策略**：

| 操作 | 缓存 key | 有效期 | 说明 |
|------|---------|--------|------|
| 分类 | `normalized_url` SHA | 7 天 | 同一 URL 分类结果稳定 |
| 摘要 | `normalized_url` SHA | 7 天 | 同一 URL 摘要不变 |
| 去重判断 | 不缓存 | — | 每次候选组不同 |
| 事件归并 | 不缓存 | — | 依赖实时事件状态 |

**预期收益**：多来源报道同一事件时，第一条调 LLM，后续 URL 相同则命中缓存。日均缓存命中率预计 10-20%。

### 4.6 监控与可观测性 [v3 新增]

> 5/6 评审指出缺少监控告警体系。

#### 健康指标

```jsonc
// data/metrics/daily-YYYY-MM-DD.json
{
  "date": "YYYY-MM-DD",
  "sources": {
    "total": 10,
    "success": 8,
    "failed": 1,
    "degraded": 1
  },
  "items": {
    "fetched": 320,
    "url_deduped": 45,
    "title_deduped": 12,
    "classified": 263,
    "partial": 5,
    "selected_for_output": 20
  },
  "llm": {
    "calls": 285,
    "tokens_input": 180000,
    "tokens_output": 45000,
    "cache_hits": 32,
    "failures": 2
  },
  "output": {
    "type": "daily_digest",
    "item_count": 20,
    "quota_distribution": { "core": 10, "adjacent": 4, "hotspot": 3, "explore": 3 }
  },
  "feedback": {
    "received": 3,
    "applied": 3
  }
}
```

#### 告警条件

| 条件 | 严重级别 | 动作 |
|------|---------|------|
| 所有来源连续 2 天采集失败 | 严重 | 在下次输出中附带告警提示 |
| LLM 日调用超过预算 80% | 警告 | 在输出尾部附带成本提示 |
| dedup-index 与近 7 天文件不一致 | 警告 | 健康巡检时自动重建 |
| 某来源连续 7 天占比 > 40% | 信息 | 周报中提示来源集中度 |
| 日报生成为空（无可用内容） | 警告 | 不发送，记录原因 |

#### 健康巡检任务（每周一次）

由 cron 触发，检查项：

1. dedup-index 是否与近 7 天 JSONL 一致
2. 活跃事件是否存在空 `item_ids`
3. 是否存在长期未归档事件（stable > 14 天）
4. 来源采集成功率汇总
5. 偏好权重极端值检查（任一 topic_weight 逼近 0 或 1）
6. 缓存文件大小与过期清理

---

# 第二部分：数据架构

---

## 5. 数据模型定义

### 5.1 NewsItem — 单条新闻 [v3 精简]

```jsonc
{
  "id": "string",               // SHA256(normalized_url)[:16]
  "title": "string",
  "url": "string",              // 原始 URL
  "normalized_url": "string",   // 去除追踪参数后的规范化 URL
  "source_id": "string",        // 关联来源 ID
  "content_summary": "string",  // LLM 生成的摘要（2-3 句）
  "categories": {
    "primary": "string",        // 主类目 ID
    "secondary": ["string"],    // 辅助类目 ID 列表
    "tags": ["string"]          // 细粒度标签
  },
  "importance_score": 0.0,      // 0-1，LLM 评估的重要性
  "event_id": "string|null",    // 归属事件 ID
  "fetched_at": "ISO8601",
  "published_at": "ISO8601|null",
  "form_type": "string",        // [v3 收缩] news|analysis|opinion|announcement|other
  "language": "string",         // zh|en|ja 等
  "dedup_status": "string",     // unique|url_dup|title_dup|event_merged
  "content_hash": "string",     // SHA256(normalized_content)[:16]
  "processing_status": "string", // raw|partial|complete
  "duplicate_of": "string|null", // 近似重复时指向主记录 ID
  "_schema_v": 2                // [v3] schema 版本升至 2
}
```

**v3 移除的字段及理由**：
- `full_content`：整个处理链从不消费此字段，存储浪费（Claude Opus 评审）
- `media_urls`：输出模板未引用，无消费场景（Claude Opus、MiniMax 评审）
- `word_count`：对评分无直接贡献（MiniMax 评审）

**v3 form_type 收缩**：从 7 种收缩为 5 种（`news|analysis|opinion|announcement|other`），合并了 `release_note`/`changelog`/`tutorial` 为上下文可区分的类型。过细的枚举在分类准确性上收益低于复杂度代价（Claude Opus 评审）。

### 5.2 Event — 事件

```jsonc
{
  "id": "string",               // "evt-" + 生成的短 ID
  "title": "string",            // 事件标题（LLM 生成）
  "summary": "string",          // 事件当前状态摘要
  "first_seen": "ISO8601",
  "last_updated": "ISO8601",
  "status": "string",           // active|stable|archived
  "topic": "string",            // 主类目 ID
  "importance": 0.0,
  "keywords": ["string"],       // 3-5 个关键词
  "item_ids": ["string"],       // 关联 NewsItem ID 列表
  "timeline": [
    {
      "news_id": "string",
      "relation": "string",     // [v3 收缩] initial|update|correction|analysis|reversal
      "timestamp": "ISO8601",
      "brief": "string"         // 一句话描述
    }
  ],
  "_schema_v": 2
}
```

**v3 时间线关系类型收缩**：9 种 → 5 种

| v2 类型 | v3 映射 | 理由 |
|---------|---------|------|
| initial_report | **initial** | 保留 |
| follow_up, test_result, patch, comparison | **update** | 合并为通用更新，由 `brief` 描述具体性质 |
| correction | **correction** | 保留，辟谣/修正有独立语义 |
| analysis, community_reaction | **analysis** | 合并，均为解读类 |
| retraction | **reversal** | 保留，重大反转有独立语义 |

> 4/6 评审建议收缩。合并后由 `brief` 字段承载细粒度描述，避免枚举维护成本。

### 5.3 Source — 来源配置

```jsonc
{
  "id": "string",               // "src-" + kebab-case 名称
  "name": "string",
  "type": "string",             // rss|github|search|official|community|ranking
  "url": "string",
  "weight": 1.0,                // 0-2
  "credibility": 0.8,           // 0-1，初始值
  "topics": ["string"],
  "enabled": true,
  "fetch_config": { },          // 各类型特有的采集参数
  "stats": {
    "total_fetched": 0,
    "last_fetch": "ISO8601|null",
    "last_hit_count": 0,
    "avg_daily_items": 0,
    "consecutive_failures": 0,
    "last_error": "string|null",
    "quality_score": 0.5,       // [v3 新增] 动态质量评分
    "dedup_rate": 0.0,          // [v3 新增] 近 7 天被去重淘汰的比例
    "selection_rate": 0.0       // [v3 新增] 近 7 天被选入日报的比例
  },
  "status": "active"            // [v3 新增] active|degraded|disabled
}
```

### 5.4 UserPreference — 用户偏好（5 层模型）[v3 收缩]

> GPT-5.4 评审建议 MVP 阶段收缩到 5 层，`judgment_angles` 和 `depth_preference` 的复杂分支逻辑延后。

```jsonc
{
  // 第 1 层：主题偏好
  "topic_weights": {
    "ai-models": 0.5,           // 冷启动默认 0.5
    "dev-tools": 0.5,
    "tech-products": 0.5,
    "business": 0.5,
    "finance": 0.5,
    "macro-policy": 0.5,
    "international": 0.5,
    "security": 0.5,
    "open-source": 0.5,
    "gaming": 0.5,
    "science": 0.5,
    "breaking": 0.5
  },

  // 第 2 层：来源信任
  "source_trust": { },          // "src-xxx": 0.9，未配置则用 Source.credibility

  // 第 3 层：信息形态偏好
  "form_preference": {
    "news": 0.0,
    "analysis": 0.0,
    "opinion": 0.0,
    "announcement": 0.0,
    "other": 0.0
  },

  // 第 4 层：风格与容忍度
  "style": {
    "density": "medium",            // low|medium|high
    "repetition_tolerance": "low",
    "exploration_appetite": 0.3,    // 0-1
    "rumor_tolerance": "low"
  },

  // 第 5 层：样本反馈
  "feedback_samples": {
    "liked_items": [],              // 最近 100 条
    "disliked_items": [],
    "trusted_sources": [],
    "distrusted_sources": [],
    "blocked_patterns": []
  },

  // 元数据
  "version": 2,
  "last_updated": "ISO8601",
  "last_decay_at": "ISO8601|null",
  "total_feedback_count": 0,
  "feedback_processing_enabled": true  // kill switch
}
```

**v3 移除/延后的层**：
- `depth_preference`：延后到 Phase 3，初期固定为 "moderate"
- `judgment_angles`：延后到 Phase 3，冷启动样本不足时效果不明显
- `tracked_event_types`：合并到 `blocked_patterns` 的对立面，通过正向反馈自然学习

**保留扩展接口**：Phase 3 扩展回 7 层时，新增字段即可，不影响已有数据。

### 5.5 FeedbackEntry — 反馈条目 [v3 简化]

```jsonc
{
  "feedback_id": "string",      // "fb-" + timestamp-millis + random4
  "timestamp": "ISO8601",
  "type": "string",             // more|less|trust_source|distrust_source|like|dislike|block_pattern|adjust_style
  "target_type": "string",      // topic|source|news_item|form|style
  "target_id": "string",
  "value": "string"             // 用户原始反馈文本
}
```

**v3 简化**：
- `feedback_id` 生成改为时间戳+随机数，无需密码学强度（Qwen 评审）
- 移除 `system_decay` 和 `revert_feedback` 类型，衰减改为直接执行，撤销改为手动修改（5/6 建议简化）
- 移除 `track_event` 类型，事件跟踪通过 `like` 关联事件的新闻实现

---

## 6. 存储与目录结构设计

### 6.1 工作空间目录结构 [v3 更新]

```text
<skill-workspace>/
├── SKILL.md
├── references/                       # [v3 新增] 拆分的引用文档
│   ├── data-models.md
│   ├── prompts/
│   │   ├── classify.md
│   │   ├── summarize.md
│   │   ├── dedup.md
│   │   └── merge-event.md
│   ├── output-templates.md
│   ├── feedback-rules.md
│   └── scoring-formula.md
├── scripts/                          # [v3 新增] 确定性逻辑脚本
│   ├── dedup-index-rebuild.sh
│   ├── data-archive.sh
│   └── health-check.sh
├── config/
│   ├── sources.json
│   ├── preferences.json
│   ├── categories.json
│   └── budget.json                   # [v3 新增]
├── data/
│   ├── news/
│   │   ├── YYYY-MM-DD.jsonl
│   │   └── dedup-index.json
│   ├── events/
│   │   ├── active.json
│   │   └── archive/
│   │       └── YYYY-MM.json
│   ├── feedback/
│   │   ├── log.jsonl
│   │   └── backup/
│   ├── cache/                        # [v3 新增]
│   │   ├── classify-cache.json
│   │   └── summary-cache.json
│   └── metrics/                      # [v3 新增]
│       └── daily-YYYY-MM-DD.json
└── output/
    └── latest-digest.md
```

### 6.2 数据生命周期

| 数据类型 | 保留策略 | 说明 |
|---------|---------|------|
| NewsItem JSONL | 30 天 | 超过 30 天归档或删除 |
| dedup-index | 7 天滚动 | 每周健康巡检时重建 |
| Event (active) | 直到 archived | stable 后 7 天自动归档 |
| Event (archived) | 永久 | 按月归档 |
| Feedback log | 90 天明细 [v3 修改] | 90 天后仅保留统计摘要，不再永久保留明细 |
| Preferences | 永久 | 随反馈更新 |
| LLM 缓存 | 7 天 | 自动清理过期条目 |
| 监控指标 | 30 天 | 超过 30 天归档或删除 |

### 6.3 容量估算

- 500 条/天 × 30 天 ≈ 15,000 条 NewsItem
- 每条约 0.5KB（移除 full_content 后）→ 日 ~250KB，月 ~7.5MB
- dedup-index: ~200KB
- 活跃事件: < 1MB
- LLM 缓存: < 500KB
- 监控指标: < 1MB/月
- **整体工作空间: < 30MB / 月**

### 6.4 Schema 兼容读取约定

- 每条记录含 `_schema_v` 标识版本
- 读取时：缺失字段用默认值推导，未知字段忽略
- JSONL 中允许不同版本记录共存，不回填历史数据

---

# 第三部分：功能模块设计

---

## 7. 来源管理

### 7.1 来源类型

| 类型 ID | 名称 | 采集工具 | 解析方式 |
|---------|------|---------|---------|
| `rss` | RSS / Atom | `web_fetch` | 解析 XML，提取 title/link/description/pubDate |
| `github` | GitHub Release / Repo | `web_fetch` (GitHub API) | 解析 JSON，提取 release note |
| `official` | 官方公告 | `web_fetch` 或 `browser` | LLM 提取公告信息 |
| `search` | 搜索类 | `web_search` | 基于关键词搜索，LLM 过滤 |
| `community` | 社区 | `browser` | 渲染页面后 LLM 提取 |
| `ranking` | 热门榜单 | `web_fetch` 或 `browser` | LLM 提取排名条目 |

### 7.2 来源管理能力

用户通过自然语言管理来源，并遵循以下交互规则 [v3 新增]：

| 操作 | 示例 | 确认要求 |
|------|------|---------|
| 添加来源 | "添加 RSS：https://..." | 不需确认，即时生效 |
| 删除来源 | "删除来源 xxx" | **需二次确认** |
| 启用/禁用 | "暂停采集 xxx" | 不需确认 |
| 调整权重 | "提高 xxx 的权重" | 不需确认 |
| 查看状态 | "列出所有来源" | — |

**输入歧义处理** [v3 新增]：

- 用户说"以后少看这个" → 追问："是想降低这个来源的权重，还是减少这个主题的推送？"
- 多个来源名称相似 → 列出候选，让用户选择
- 不明确的操作目标 → 默认不执行，向用户确认

### 7.3 来源扩展原则

**数据级扩展**（通过配置完成，不需要修改 Skill）：新增 RSS 源、GitHub 仓库、搜索关键词

**逻辑级扩展**（需要修改 Skill 指令）：全新来源类型、特殊解析逻辑、需要认证的来源

### 7.4 多语言处理策略 [v3 新增]

> 5/6 评审指出多语言策略缺失。

| 处理环节 | 策略 |
|---------|------|
| 采集 | 不限语言，保留原始语言标记 `language` 字段 |
| 去重 | 不同语言的新闻独立去重，不跨语言比较标题 |
| 事件归并 | 允许跨语言归并（同一事件的中英文报道），由 LLM 根据事件内容判断 |
| 摘要生成 | 统一输出中文摘要，标题保留原文（括号附中文翻译） |
| 输出展示 | 格式示例：`[原文标题]（中文翻译） — 来源` |

**Phase 0-1**：仅处理中文和英文来源，其他语言标记为 `other` 不做特殊处理
**Phase 2+**：可扩展到日语等其他语言

### 7.5 来源健康度与动态评估 [v3 新增]

> 5/6 评审指出来源 credibility 是静态的，缺少动态重评估。

**健康度指标**（自动计算，存储于 `source.stats`）：

| 指标 | 计算方式 | 用途 |
|------|---------|------|
| `quality_score` | `selection_rate × 0.4 + (1 - dedup_rate) × 0.3 + 采集成功率 × 0.3` | 动态来源质量综合评分 |
| `dedup_rate` | 近 7 天该来源新闻被去重淘汰的比例 | 识别低信号来源 |
| `selection_rate` | 近 7 天该来源新闻被选入日报的比例 | 识别高价值来源 |

**自动降级规则**：

- `quality_score < 0.2` 连续 14 天 → 自动标记 `status: "degraded"`，降低采集频率
- `quality_score` 恢复到 > 0.3 连续 7 天 → 自动恢复 `status: "active"` [v3：补充 Kimi 评审指出的自动恢复机制]
- 所有自动状态变更记录到监控指标

**用户可查看**：`"某来源最近表现怎么样"` → 输出健康度面板

---

## 8. 新闻分类与主题体系

### 8.1 分类结构

```text
顶层类目（primary）→ 标签（tags）
```

> v3 简化：取消 `secondary` 中层主题层级，直接用多标签分类。对 LLM 来说"一个 primary + 多个 tags"比三层结构更容易稳定执行。

### 8.2 顶层类目定义

保持 12 个顶层类目不变（ai-models, dev-tools, tech-products, business, finance, macro-policy, international, security, open-source, gaming, science, breaking）。

每个类目含 `adjacent` 字段定义邻近类目，用于防茧房配额计算。详细定义见 `config/categories.json`。

### 8.3 分类 Prompt 模板 [v3 新增]

> Claude Opus 评审指出核心 LLM Prompt 完全缺失，是重大风险。

以下为 `references/prompts/classify.md` 的核心内容：

```text
你是一个新闻分类助手。请对以下新闻进行分类和重要性评估。

## 可选类目
{categories_list}

## 输入新闻（批量，每条以 --- 分隔）
{news_batch}

## 要求
对每条新闻返回 JSON：
{
  "id": "新闻ID",
  "primary": "最相关的一个类目ID",
  "tags": ["细粒度标签，kebab-case，2-5个"],
  "importance_score": 0.0-1.0,
  "form_type": "news|analysis|opinion|announcement|other",
  "reasoning": "一句话分类理由（用于调试，不写入数据）"
}

## 重要性评分参考
- 0.9-1.0：影响广泛的重大事件（大公司重大决策、重大安全事件、影响千万级用户的变更）
- 0.7-0.8：显著的行业/社区事件（重要产品发布、知名项目重大更新）
- 0.5-0.6：值得关注的动态（常规产品更新、行业观察、有价值的分析）
- 0.3-0.4：一般资讯（常规新闻、日常动态）
- 0.0-0.2：低信息密度（重复报道、标题党、纯营销内容）
```

### 8.4 摘要 Prompt 模板 [v3 新增]

`references/prompts/summarize.md` 核心内容：

```text
为以下新闻生成简洁的中文摘要。

## 要求
- 长度：2-3 句话
- 风格：信息密度高，不要空泛描述
- 包含：核心事实 + 为什么重要/影响是什么
- 非中文新闻：用中文撰写摘要，标题保留原文

## 输入
标题：{title}
来源：{source_name}
内容：{content_snippet}

## 输出
仅返回摘要文本，不要额外标记。
```

---

## 9. 偏好系统

### 9.1 设计原则

偏好系统采用 **5 层模型**（Phase 0-2），未来可扩展回 7 层。5 层已覆盖核心个性化需求：

1. **主题偏好** — 关注什么领域
2. **来源信任** — 信任哪些来源
3. **形态偏好** — 喜欢什么类型的内容
4. **风格与容忍度** — 输出密度、探索比例、传闻容忍
5. **样本反馈** — 具体的喜恶样本

### 9.2 冷启动策略

1. 所有 `topic_weights` 设为 `0.5`
2. `exploration_appetite` 设为 `0.3`（较高探索）
3. `form_preference` 全部为 `0.0`
4. 其他保持默认

前几次输出偏向均匀分布，通过反馈逐步收敛。**不设初始问卷**，降低使用门槛。

### 9.3 新闻评分公式

```text
final_score =
  importance_score × 0.25            // 客观重要性 [0,1]
  + topic_weight(primary) × 0.20     // 主题匹配 [0,1]
  + source_trust(source_id) × 0.10   // 来源信任 [0,1]
  + form_preference_norm × 0.10      // 形态匹配 [0,1]
  + feedback_boost × 0.10            // 样本反馈加成 [0,1]
  + recency_score × 0.15            // 时效性 [0,1]
  + event_boost × 0.10              // 关联热门事件加成 [0,1]
```

**计算规则**：
- `form_preference_norm = (form_preference + 1) / 2`
- `recency_score = max(0, 1 - hours_since_published / 48)`
- `event_boost = 0.5` 如果关联事件 status == "active" 且 importance >= 0.7，否则 0
- `feedback_boost` 基于 liked/disliked 样本的类目相似度计算
- `published_at` 缺失 → 使用 `fetched_at`，`recency_score` 额外 ×0.8
- 所有维度 clamp 到 [0, 1]

> 评分公式参数为初始值，Phase 1 上线后通过用户反馈观测效果并调优。具体调优方法：对比用户 like/dislike 的新闻与其 final_score 排名的相关性。

---

## 10. 防茧房机制

### 10.1 设计原则

防茧房是 **内建约束**，不是附加功能。个性化的目标是提高命中率的同时保留外部世界的重要入口。

### 10.2 内容配额

| 配额层 | 日报 | 周报 | 说明 |
|--------|------|------|------|
| 核心兴趣 | 50% | 40% | topic_weight >= 0.7 |
| 邻近兴趣 | 20% | 20% | 核心类目的 adjacent |
| 公共热点 | 15% | 20% | importance >= 0.8 且不在核心/邻近 |
| 探索内容 | 15% | 20% | 其余类目中高质量内容 |

### 10.3 配额执行算法 [v3 简化]

```text
1. 候选新闻按 final_score 降序排列
2. 按类目分组：core / adjacent / hotspot / explore
3. 确定目标条数 N
4. 按配额比例从各组取 top-K
5. 配额不足时：按 explore → adjacent → hotspot → core 顺序让渡
   （简单链式让渡，不做双向复杂规则）
6. 合并输出
```

> v3 简化：4 层让渡优先级收缩为单向链式让渡（GLM-5 建议"不足时顺延给下一优先级组"）。

### 10.4 反向多样性约束

- 同一主题连续 3 天占比 > 60% → 该主题本日配额上限降至 50%
- 同一来源连续 3 天占比 > 30% → 该来源本日配额上限降至 20%
- 同一事件连续推送 > 3 天 → 仅在有新进展时推送

### 10.5 热点注入规则

- `importance_score >= 0.8` 的新闻强制进入候选池
- 重大安全事故、平台级服务故障等强制进入
- 热点也要经过质量判断和去重，不是原样搬运

### 10.6 偏好纠偏

- 顶层类目最小覆盖：即使用户从不点击，保留 ≥ 2% 曝光（注入在配额分配后）
- 周报中至少覆盖 5 个不同类目
- 每 7 天自动提升 `exploration_appetite`（+0.05，上限 0.4）

---

## 11. 去重与事件归并

### 11.1 三层去重策略

#### 第 1 层：链接级去重

URL 规范化规则：去除 `utm_*` 等追踪参数 → 统一 https → 去除 www → 去除尾部 / → 小写 host → SHA256[:16]

查询 `dedup-index.json`，已存在则跳过。

#### 第 2 层：标题近似去重（三阶段收缩）

**阶段 A：规则归一化** — 去标点/空格差异、去常见前后缀

**阶段 B：Jaccard 收缩** — bigram 分词 + Jaccard >= 0.6 进入候选组，按来源+类目分组。预期 500 条/天 → 20-50 候选对

**阶段 C：LLM 精确判断** — 仅候选组执行，批量模式（每组 ≤ 10 条），每日约 5-15 次 LLM 调用

**去重判断 Prompt 模板** [v3 新增]（`references/prompts/dedup.md`）：

```text
以下标题可能是关于同一新闻的不同报道。请判断哪些是近似重复的。

## 候选标题组
{title_list_with_ids}

## 判断标准
- "近似重复"指：报道的是同一件事的同一个角度，只是来源/措辞不同
- "不重复"指：虽然主题相关，但报道的是不同事实或不同角度
- 同一事件的不同进展（如"发布"vs"评测"）不算重复，应保留

## 输出
返回 JSON 数组，每个元素为一组重复新闻的 ID 列表：
[["id1", "id2"], ["id3", "id4", "id5"]]
无重复则返回空数组 []
```

#### 第 3 层：事件级归并

**Step 1 — topic 预筛选**：同 topic 活跃事件（50-200 → 5-20）

**Step 2 — 关键词快速匹配**：事件 `keywords[]` 与新闻标题 token overlap >= 2

**Step 3 — LLM 精确归并**：仅候选事件（1-5 个），Prompt 只放候选事件 title + summary（≤ 500 tokens）

**事件归并 Prompt 模板** [v3 新增]（`references/prompts/merge-event.md`）：

```text
一条新新闻需要判断是否属于以下已有事件之一。

## 新新闻
标题：{news_title}
摘要：{news_summary}
类目：{news_primary_category}

## 候选事件
{event_list: id, title, summary, status}

## 判断标准
- 报道的是同一个核心事件/主体 → 归并，返回事件 ID
- 仅主题相关但不是同一事件 → 不归并
- 无匹配 → 创建新事件

## 输出 JSON
{
  "action": "merge|new",
  "event_id": "事件ID（merge时）",
  "relation": "initial|update|correction|analysis|reversal",
  "brief": "一句话描述这条新闻在事件中的角色",
  "new_event_title": "新事件标题（new时）",
  "new_event_keywords": ["关键词1", "关键词2", "关键词3"]
}
```

### 11.2 Event 生命周期状态机

```text
新事件创建 → [active] ──3天无更新──► [stable] ──7天无更新──► [archived]
                 ▲                       │
                 └───── 有新关联新闻 ─────┘
```

> v3 移除 `developing` 状态，简化为三态。`active` 已表达"持续发展"语义。

---

## 12. 时间线追踪

### 12.1 目标

让用户看到事件的连续发展脉络：开始时间、当前进展、历史变化、是否值得继续关注。

### 12.2 时间线展示格式

```markdown
### {event.title}
状态: {status} | 重要性: {importance}

- {timestamp} [初始] {brief} — {source}
- {timestamp} [更新] {brief} — {source}
- {timestamp} [分析] {brief} — {source}

当前摘要: {event.summary}
```

> v3 简化：取消 Markdown 表格格式，改用 bullet list。表格在部分聊天渠道兼容性差（GPT-5.4 建议）。

---

## 13. 输出格式与内容生成

### 13.1 职责说明

本 Skill 只负责 **内容生成**。调度触发和推送投递由 OpenClaw cron + delivery 配置处理。

### 13.2 输出类型 [v3 收缩]

| 输出类型 | 触发方式 | 内容特点 |
|---------|---------|---------|
| 日报 | cron 日报任务 | 过去一天的精选整理，按配额分配，15-25 条 |
| 快讯 | cron 高频检查 | 仅 importance >= 0.85 时输出，无内容则不输出 |
| 周报 | cron 周报任务 | 回顾一周趋势，含事件时间线和跨领域总结 |

> v3 移除"晚报"和"专题追踪"：晚报与日报重叠度高，专题追踪可用事件时间线+查询替代（Claude Opus 建议）。

### 13.3 输出模板 [v3 新增解释字段]

**日报模板**：

```markdown
# 新闻日报 — {date}

## 核心关注
{对每条：标题 + 2-3 句摘要 + 来源}
{[v3 新增] 如为探索/热点位：附带推荐理由}

## 相关动态
{邻近兴趣新闻，更简短}

## 今日热点
{公共热点新闻}

## 探索发现
{探索类内容 + 推荐理由}
{推荐理由示例："推荐原因：该主题近期热度上升" / "推荐原因：你关注事件的后续进展" / "推荐原因：跨领域高信号内容"}

## 事件跟踪
{有新进展的活跃事件时间线}

---
来源: {source_count} | 处理: {total_items} 条 | 精选: {selected_items} 条
LLM 调用: {llm_calls} 次 | 缓存命中: {cache_hits} 次 [v3 新增：透明化运行成本]
```

**快讯模板**：

```markdown
**快讯** — {timestamp}

**{title}**
{2-3 句摘要}

重要性: {importance}/10 | 来源: {source_name}
{如有关联事件: "关联事件: {event.title}"}
```

### 13.4 输出控制参数

| 参数 | 默认值 | 说明 |
|------|-------|------|
| 日报条数 | 15-25 | 精选条目数量 |
| 周报条数 | 30-50 | 精选条目数量 |
| 快讯阈值 | importance >= 0.85 | 触发快讯的最低重要性 |
| 摘要长度 | 2-3 句 | 每条新闻的摘要长度 |
| 探索内容 | 开启 | 是否包含探索类推荐 |
| 低质量日缩短 | 开启 | 内容不足时缩短而非硬凑 [v3 新增] |

---

## 14. 反馈学习与历史查询

### 14.1 反馈类型与偏好影响映射

| 反馈类型 | 示例 | 影响字段 | 调整方式 |
|---------|------|---------|---------|
| `more` | "这类多推" | `topic_weights` | +0.1 |
| `less` | "这类少推" | `topic_weights` | -0.1 |
| `trust_source` | "这个来源好" | `source_trust` | +0.15 |
| `distrust_source` | "这个来源降权" | `source_trust` | -0.2 |
| `like` | "这条不错" | `feedback_samples.liked_items` | 记录 + 微调相关偏好 |
| `dislike` | "这条不想看" | `feedback_samples.disliked_items` | 记录 + 微调相关偏好 |
| `block_pattern` | "标题党不要" | `form_preference` + `blocked_patterns` | 形态 -0.2，记录模式 |
| `adjust_style` | "热点多点" | `style.*` | 直接调整风格参数 |

### 14.2 偏好更新规则 [v3 大幅简化]

#### 14.2.1 增量应用（唯一运行路径）

> v3 核心简化：取消全量重建路径、取消 applied.json 账本、取消 revert_feedback 类型。MVP 阶段这些机制的实现成本远大于收益（5/6 评审共识）。

每次任务运行时：

1. 读取 `preferences.json` + `log.jsonl`
2. 从 log 中筛选 `timestamp > preferences.last_updated` 的未处理反馈
3. 按时间顺序应用到 preferences 副本
4. 原子写入 `preferences.json`（tmp + rename）

**错误反馈处理**：用户发现偏好偏了 → 直接说"重置 xxx 主题权重"或"把 xxx 权重调到 0.5"，agent 直接修改 preferences。不需要复杂的撤销补偿机制。

**Kill Switch**：`preferences.json` 中 `feedback_processing_enabled: false` 冻结偏好更新。

#### 14.2.2 偏好衰减（简化版）[v3 重写]

> v3 简化：取消 append-only 衰减事件、取消 catch-up 算法。

**执行方式**：每次运行检查 `last_decay_at`，距今 ≥ 30 天 → 直接执行衰减

**衰减公式**：`w_new = w + (0.5 - w) × 0.05`（向均值回归 5%）

**执行后**：更新 `last_decay_at`，记录一行日志到监控指标

> 不追求完全回放一致性。等系统成熟、反馈量足够大后，再考虑升级为日志化衰减。

#### 14.2.3 权重调整范围

- 单次反馈：±0.05 ~ ±0.2
- 上下限：topic_weights [0, 1]，source_trust [0, 1]，form_preference [-1, 1]
- 大幅调整（单次 > 0.3）→ 升级确认

#### 14.2.4 自动备份

每次偏好更新前备份 `preferences.json` 到 `data/feedback/backup/`，保留最近 10 个。

### 14.3 反馈引用消歧规则

当用户反馈指向具体新闻时：

1. **消息回复关联**：回复推送消息 → 直接关联 news_id
2. **序号引用**："第 N 条" → 最近一次输出的第 N 条
3. **关键词搜索**："关于 xxx 的那条" → 最近 24h 搜索
4. **事件引用**："xxx 事件" → 匹配活跃事件
5. **无法消歧** → 列出 2-3 个候选让用户选择

### 14.4 历史查询能力

| 查询类型 | 示例 | 数据定位方法 |
|---------|------|-------------|
| 最近动态 | "最近 24 小时有什么" | 读取当日 JSONL |
| 主题回顾 | "AI 这周有什么" | 按 primary 过滤近 7 天 JSONL |
| 事件跟踪 | "某事件后续" | 查 active.json |
| 热点扫描 | "高热但不在偏好里的" | importance 过滤 + 偏好交叉 |
| 来源分析 | "某来源最近推什么" | 按 source_id 过滤 |
| 来源健康 | "某来源表现怎样" | 读取 source.stats [v3 新增] |
| 偏好查看 | "我的偏好是什么" | 读取 preferences.json，文字化描述 [v3 新增] |

> **查询性能说明**：当前 JSONL 无索引，Phase 0-2 通过按日分文件 + 限定时间范围实现可接受的查询速度。Phase 3 若查询性能成为瓶颈，考虑引入 SQLite 或索引文件。

---

# 第四部分：执行路线

---

## 15. 设计原则、反模式与合规

### 15.1 应遵循的原则

1. **系统级而非插件级** — 统一 Skill 编排所有功能
2. **多维偏好而非关键词过滤** — 5+层模型
3. **内建约束而非附加功能** — 防茧房是核心设计约束
4. **事件级而非链接级** — 新闻处理上升到事件维度
5. **平台能力复用** — 不重复造轮子
6. **成本可控** — LLM 调用有预算、有缓存、有熔断 [v3 新增]
7. **可观测** — 关键指标可监控，异常可发现 [v3 新增]

### 15.2 应避免的反模式

1. 不要把偏好理解成"尽量少给用户意外"
2. 不要把热点理解成"热搜榜原样搬运"
3. 不要把时间线理解成"按时间倒序堆标题"
4. 不要把来源扩展做成无限拆碎的 Skill 列表
5. 不要把一切都塞进 SKILL.md — 详细规范拆分到 references/ [v3 新增]
6. 不要追求一步到位的完美 — 先跑通再优化 [v3 新增]

### 15.3 隐私与合规基础约定 [v3 新增]

> Qwen 评审指出隐私合规完全缺失。

| 约定 | 说明 |
|------|------|
| 数据存储范围 | 仅存储新闻摘要和元数据，不存储原文全文 |
| 来源抓取合规 | 尊重 robots.txt；GitHub API 使用合规认证；不绕过付费墙 |
| 用户数据 | 偏好数据仅存储于用户工作空间，不发送到外部服务（Standing Orders 已约束） |
| 内容版权 | 输出中标注来源和原文链接，摘要为 LLM 改写而非原文复制 |

---

## 16. MVP 定义与分阶段路线图

### Phase 0 — 最小可用版本 [v3 合并为单阶段]

> v3 变更：将 0A/0B/0C 合并为单一 Phase 0。三者依赖紧密、交付周期短，拆分增加管理开销（Qwen 评审）。

**目标**: 端到端跑通：1 个 RSS 来源 → 采集 → 去重 → 分类/摘要 → 日报生成

**交付物**:
- 完整目录结构 + SKILL.md 框架 + 引用文档骨架
- categories.json + preferences.json（冷启动）+ sources.json（1 个 RSS）
- budget.json 初始配置
- RSS 采集指令 + 链接去重 + NewsItem 写入
- LLM 分类 + 摘要生成 + 基础评分排序 + 日报 Markdown 生成

**平台验证**:
- isolated session 工作空间访问
- exec 脚本执行权限
- cron delivery 配置
- 单次 agent turn 超时限制

**完成标准**:
- 手动触发采集 → 写入 JSONL → 重复触发无重复记录
- 日报有分类标签、摘要、来源、评分排序
- 空输入不生成空日报
- LLM 调用次数记录到 budget.json
- 监控指标文件生成

**集成验证**: 触发 → 采集 → 去重 → 分类/摘要 → 评分 → 日报，端到端跑通

### Phase 1 — 基础系统

**目标**: 多来源类型 + 偏好管理 + 基础反馈循环

**新增能力**:
- 支持 GitHub、搜索、网页等来源类型
- 来源管理（自然语言增删改查 + 交互规则）
- 基础偏好系统（主题权重 + 来源信任 + 形态偏好）
- 基础反馈处理（more/less/trust/distrust/like/dislike）
- 快讯输出类型
- LLM 缓存层
- 来源健康度指标采集

**完成标准**:
- 支持 ≥ 3 种来源类型
- 用户反馈能影响后续输出排序
- 快讯在高重要性事件时触发
- 缓存命中率 > 0（可观测）

**数据迁移**: 已有 NewsItem 补 `_schema_v: 2`

### Phase 2 — 智能处理

**目标**: 事件级处理 + 时间线 + 防茧房

**新增能力**:
- 标题近似去重（Jaccard + LLM）
- 事件归并 + Event 生命周期管理
- 时间线追踪
- 防茧房配额机制 + 反向多样性约束
- 多语言支持（中+英）
- 健康巡检任务
- 输出解释字段

**完成标准**:
- 同一事件多条新闻合并展示
- 日报中配额比例可观测
- 持续发展事件有时间线视图
- 英文来源新闻正确处理

**数据迁移**: 已有 Event 补 `keywords: []` 和 `_schema_v: 2`

### Phase 3 — 闭环系统

**目标**: 完整反馈闭环 + 历史查询 + 高级偏好

**新增能力**:
- 扩展回 7 层偏好模型（新增 depth_preference + judgment_angles）
- 偏好衰减机制
- 周报输出（含趋势分析）
- 历史查询（自然语言）
- 偏好可视化（文字化描述当前偏好状态）
- 来源质量自动评估与自动降级/恢复

**完成标准**:
- 偏好不会极端固化（衰减机制有效）
- 周报覆盖 ≥ 5 个类目
- 自然语言查询历史可用
- 用户可查看偏好状态

**如查询性能成为瓶颈**: 考虑引入 SQLite 或构建索引文件

---

## 附录 A：v2 → v3 评审驱动的完整变更记录

| 变更 | 评审来源 | 采纳理由 |
|------|---------|---------|
| 新增 LLM 成本预算 | 6/6 一致 | 最大隐患，必须补充 |
| 新增上下文窗口管理 | Claude Opus, GLM-5, MiniMax | 工程实现的硬约束 |
| 新增 LLM 缓存层 | 5/6 | 直接降低成本和延迟 |
| 新增监控体系 | 5/6 | 生产环境必备 |
| 新增多语言策略 | 5/6 | 现实场景刚需 |
| 新增来源健康度动态评估 | 5/6 | 替代静态 credibility |
| 新增 LLM Prompt 模板 | Claude Opus | 核心决策点不能留空白 |
| 新增输出解释字段 | GPT-5.4, Qwen | 提升用户信任 |
| 新增隐私合规约定 | Claude Opus, Qwen | 合规基线 |
| 新增交互规则（消歧、确认） | GPT-5.4 | 提升 Skill 可用性 |
| SKILL.md 模块化拆分 | GPT-5.4, Claude Opus, MiniMax | 避免巨型单文件 |
| 平台能力待验证清单 | Claude Opus | 减少实施风险 |
| 偏好 7 层→5 层 | GPT-5.4 | MVP 阶段收缩复杂度 |
| 移除 full_content/media_urls/word_count | Claude Opus, MiniMax | 无消费场景 |
| form_type 7→5 种 | Claude Opus | 过细分类收益低 |
| 时间线关系 9→5 种 | 4/6 | brief 字段可承载细粒度 |
| 事件状态 4→3 态 | — | developing 与 active 语义重叠 |
| 输出类型 5→3 种 | GLM-5, Claude Opus | 晚报/专题可用现有能力替代 |
| 简化锁机制 | 4/6 | 单用户低并发场景足够 |
| 简化反馈系统 | 5/6 | 取消全量重建/撤销协议/账本 |
| 简化偏好衰减 | 4/6 | 取消 catch-up/append-only |
| 合并 Phase 0 子阶段 | Qwen | 三者紧耦合，拆分增加管理成本 |
| 简化配额让渡规则 | GLM-5 | 单向链式替代双向复杂逻辑 |
| 时间线格式表格→列表 | GPT-5.4 | 聊天渠道兼容性 |
| feedback_id 简化 | Qwen | 无需密码学强度 |
| Feedback log 90 天→统计 | Kimi | 永久明细膨胀过大 |

## 附录 B：延后到未来版本的能力

以下能力在评审中被多个模型提及，但不适合在 Phase 0-3 实现：

| 能力 | 延后原因 | 预期阶段 |
|------|---------|---------|
| Embedding 替代 Jaccard | 需额外依赖，当前规模不需要 | Phase 4+ |
| 反馈撤销 + 全量重建 | 实现成本高，手动修改已够用 | Phase 4+ |
| 日志化衰减协议 | 简单衰减已满足需求 | Phase 4+ |
| A/B 测试框架 | 单用户场景无对照组 | 多用户版本 |
| 多用户支持 | 架构变动大 | V2 |
| 情感分析 | 优先级低 | Phase 4+ |
| 热点预测 | 数据积累不足 | Phase 4+ |
| 来源自动发现 | 需要充分的用户反馈数据 | Phase 3+ |
| SQLite 迁移 | 30 天 JSONL 性能可接受 | 按需 |

---

*文档版本：v3 | 基于 6 个 AI 模型独立评审优化 | 2026-03-31*
