# OpenClaw 个性化新闻系统计划文档

> **v2 变更摘要**：本文档基于 v1 评审优化，主要变更包括：运行保障规则（§4.1-4.2）、数据模型扩展（§5）、评分公式优化（§9.4）、去重策略收敛（§11.1）、反馈系统增强（§14.2-14.4）、Phase 0 拆分（§16）。详见各章节内的 `[v2 新增]` 标记。

---

# 第一部分：基础定义

---

## 1. 项目定位与目标

本文档定义一个基于 OpenClaw 的个性化新闻研究与推送 Skill 的完整设计规格。

本文档覆盖：

- 产品边界与功能范围
- 信息结构与数据模型
- 各子系统的具体设计与实现方式
- OpenClaw 平台集成映射
- MVP 定义与分阶段演进路线

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

这个系统不是简单的"RSS 搬运器"或"热搜转发器"，而是一个：

- 有主题意识
- 有偏好记忆
- 有去重能力
- 有事件归并能力
- 有时间线能力
- 有探索与纠偏能力

的新闻编排 Skill。

### 2.2 形态决策

项目主体定为一个 OpenClaw Skill，包含：

- 一个 `SKILL.md` 作为编排指令中心
- 一组工作空间文件作为数据与配置存储
- 利用 OpenClaw 原生工具完成采集、调度、推送

### 2.3 Skill 与平台的职责边界

| 职责 | 负责方 | 说明 |
|------|--------|------|
| 内容处理逻辑 | **Skill** | 分类、去重、归并、评分、摘要生成 |
| 偏好管理 | **Skill** | 7 层偏好模型的存储与更新 |
| 事件跟踪 | **Skill** | 事件归并、时间线维护、生命周期管理 |
| 输出生成 | **Skill** | 日报/周报/快讯等内容的格式化输出 |
| 来源采集触发 | **OpenClaw cron** | 定时触发 agent 执行采集任务 |
| 推送渠道 | **OpenClaw message/delivery** | Telegram/Discord/Slack 等渠道投递 |
| 调度管理 | **OpenClaw cron** | cron 表达式、频率、时区等 |
| 用户交互通道 | **OpenClaw 平台** | 用户通过聊天通道与 agent 交互 |

### 2.4 为什么选择 Skill 形态

OpenClaw Skill 适合承载：

- 规则与策略（偏好处理、配额分配、去重规则）
- 编排逻辑（多步骤的新闻处理流水线）
- 行为边界（什么该推、什么该过滤、什么该跟踪）
- 格式规范（输出模板、摘要风格）

Skill 不是重型插件，而是指令文档 + 工作空间数据的组合。Agent 根据 Skill 指令理解该做什么，利用平台工具去执行。

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

### 3.1.1 SKILL.md 正文结构 [v2 新增]

SKILL.md 正文应包含以下部分（按序）：

1. **角色定义** — "你是一个个性化新闻编排助手，运行在 OpenClaw 平台上"
2. **工作空间说明** — 列出各配置和数据文件的路径、格式、用途
3. **采集指令** — 按来源类型（RSS/GitHub/Search/Browser）分别说明采集步骤和工具调用
4. **处理指令** — 分类、去重、归并的步骤流程和 LLM prompt 模板
5. **评分与配额** — 评分公式参数、防茧房配额规则
6. **输出指令** — 日报/晚报/快讯/周报的生成条件和输出模板
7. **反馈指令** — 反馈类型识别、偏好更新规则、消歧流程
8. **查询指令** — 历史查询类型和数据定位方法
9. **运行约束** — Standing Orders 的执行边界和升级条件

每部分应包含明确的步骤编号和条件判断，使 agent 能够按指令直接执行。

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
| 脚本执行 | `exec` | 执行辅助脚本（如数据清理、索引重建） |

### 3.3 Cron Job 配置参考

以下为 Skill 配合使用的 cron job 配置示例（由用户在 OpenClaw 侧配置，不在 Skill 内定义）：

**日报（每天早 8 点）：**

```json
{
  "name": "新闻日报",
  "schedule": { "kind": "cron", "expr": "0 8 * * *", "tz": "Asia/Shanghai" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "执行新闻日报任务：采集来源、处理新闻、生成日报输出。",
    "lightContext": false
  },
  "delivery": {
    "mode": "announce",
    "channel": "telegram",
    "to": "<chat-id>"
  }
}
```

**快讯检查（每 2 小时）：**

```json
{
  "name": "快讯检查",
  "schedule": { "kind": "cron", "expr": "0 */2 * * *", "tz": "Asia/Shanghai" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "执行快讯检查：采集高优先来源，仅在发现重要突发新闻时生成快讯输出。无重要内容则不输出。",
    "lightContext": true
  },
  "delivery": {
    "mode": "announce",
    "channel": "telegram",
    "to": "<chat-id>",
    "bestEffort": true
  }
}
```

**周报（每周日晚 8 点）：**

```json
{
  "name": "新闻周报",
  "schedule": { "kind": "cron", "expr": "0 20 * * 0", "tz": "Asia/Shanghai" },
  "sessionTarget": "isolated",
  "payload": {
    "kind": "agentTurn",
    "message": "执行新闻周报任务：回顾本周新闻，生成周报输出，包含趋势分析和事件时间线。",
    "model": "opus",
    "thinking": "medium"
  },
  "delivery": {
    "mode": "announce",
    "channel": "telegram",
    "to": "<chat-id>"
  }
}
```

### 3.4 Standing Orders 设计

在 agent 的 `AGENTS.md` 中定义新闻 Skill 的自主执行边界：

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

### 禁止事项
- 不得自行添加未经用户确认的来源
- 不得将偏好数据发送到外部服务
- 不得在无新内容时强制生成空输出
```

---

## 4. 顶层架构

```text
主 Skill（编排中心 — SKILL.md）
├─ 来源层（按来源类型分组）          → web_fetch / browser / web_search
├─ 分类层（多标签主题分类）          → LLM 分类
├─ 偏好层（7 层兴趣模型）            → config/preferences.json
├─ 去重归并层（新闻项 → 事件）       → LLM 判断 + URL 索引
├─ 时间线层（事件生命周期跟踪）      → data/events/
├─ 输出层（日报/周报/快讯格式生成）  → LLM 生成 + 模板
├─ 反馈学习层（用户修正 → 偏好更新）→ data/feedback/ → config/preferences.json
└─ 防茧房层（配额约束，贯穿全流程）  → 配额算法
```

系统处理流水线：

```text
来源采集 → 链接去重 → LLM 分类/摘要 → 标题去重 → 事件归并
    → 偏好评分 → 防茧房配额分配 → 输出格式化 → 推送
```

### 4.1 运行保障规则 [v2 新增]

#### 4.1.1 单实例互斥（原子锁）

采用原子 `mkdir` 作为锁原语（POSIX 保证 mkdir 是原子操作）：

**获取锁：**
1. 尝试 `mkdir data/.lock.d`（原子操作，成功则获取锁）
2. 成功 → 在 `data/.lock.d/meta.json` 写入（先写 `meta.json.tmp` 再 `rename`）：
   ```json
   { "run_id": "run-20260331-080000-a1b2", "started_at": "ISO8601", "heartbeat_at": "ISO8601", "task_type": "daily_digest" }
   ```
3. 失败（EEXIST）→ 读取 `meta.json` 的 `heartbeat_at`：
   - Case A（meta 存在且可读）：heartbeat < 10 分钟 → 锁有效，跳过；heartbeat ≥ 10 分钟 → stale，接管
   - Case B（meta 不存在/损坏）：目录 mtime < 2 分钟 → 等 5 秒重试；mtime ≥ 2 分钟 → stale，接管

**接管锁：** `rename("data/.lock.d", "data/.lock.stale.{run_id}")` → 重新 `mkdir` → 写 meta

**Heartbeat：** 持有锁的任务每 2 分钟更新 `heartbeat_at`

**释放锁：** `unlink("meta.json")` → `rmdir("data/.lock.d/")`

#### 4.1.2 Run ID 与原子写入

- 每次运行分配唯一 `run_id`（格式：`run-YYYYMMDD-HHmmss-random4`）
- 所有数据写入先写临时文件 `*.tmp.{run_id}`，完成后 rename（POSIX 原子操作）
- 崩溃恢复：启动时扫描 `data/**/*.tmp.*`，创建 > 10 分钟的 → 删除

#### 4.1.3 幂等与去重（两类语义）

**Exact duplicate（完全重复）— 不落盘：**
- 匹配条件：`normalized_url` SHA 已在 dedup-index，或 `content_hash` 已在当日 JSONL
- 行为：完全跳过

**Near duplicate（近似重复）— 保留从属记录：**
- 匹配条件：通过 §11.1 标题近似去重识别
- 行为：写入 JSONL，标记 `dedup_status: "title_dup"`, `duplicate_of: "{主记录ID}"`

**断点续跑：** `processing_status: "raw"` 的记录，下次运行补充分类/摘要

#### 4.1.4 超时与降级

- 单次采集任务硬超时：5 分钟
- 来源按权重降序采集，超时时低优先来源被跳过
- 连续 3 次失败：采集间隔 ×2；连续 7 次：标记 `source.status: "degraded"`

### 4.2 容错规则 [v2 新增]

**来源采集失败：** 记录 `source.stats.last_error` 和 `consecutive_failures`，连续 7 次标记 degraded

**LLM 调用失败：** 跳过分类/摘要，标记 `processing_status: "partial"`。Partial 新闻在日报中仅显示标题+来源

**格式异常：** RSS 非标准 XML → 宽松解析；LLM 返回非 JSON → 重试 1 次

---

# 第二部分：数据架构

---

## 5. 数据模型定义

### 5.1 NewsItem — 单条新闻

```jsonc
{
  "id": "string",              // SHA256(normalized_url) 的前 16 位
  "title": "string",
  "url": "string",             // 原始 URL
  "normalized_url": "string",  // 去除 utm 等参数后的规范化 URL
  "source_id": "string",       // 关联来源 ID
  "content_summary": "string", // LLM 生成的摘要（2-3 句）
  "full_content": "string",    // 可选，原文内容（用于深度分析）
  "categories": {
    "primary": "string",       // 主类目 ID，如 "ai-models"
    "secondary": ["string"],   // 辅助类目 ID 列表
    "tags": ["string"]         // 细粒度标签
  },
  "importance_score": 0.0,     // 0-1，LLM 评估的重要性
  "event_id": "string|null",   // 归属事件 ID，未归并时为 null
  "fetched_at": "ISO8601",     // 采集时间
  "published_at": "ISO8601|null", // 发布时间（如可解析）
  "form_type": "string",       // 内容形态：release_note|changelog|analysis|news|opinion|tutorial|announcement
  "language": "string",        // 语言代码：zh|en|ja 等
  "dedup_status": "string",    // unique|url_dup|title_dup|event_merged
  "_schema_v": 1,              // [v2 新增] schema 版本号
  "content_hash": "string",    // [v2 新增] SHA256(normalized_content)[:16]
  "word_count": 0,             // [v2 新增] 原文字数
  "media_urls": [],            // [v2 新增] 关联图片/视频 URL
  "processing_status": "string", // [v2 新增] raw|partial|complete
  "duplicate_of": "string|null"  // [v2 新增] 近似重复时指向主记录 ID
}
```

### 5.2 Event — 事件

```jsonc
{
  "id": "string",              // "evt-" + 生成的短 ID
  "title": "string",           // 事件标题（LLM 生成）
  "summary": "string",         // 事件当前状态摘要（随更新刷新）
  "first_seen": "ISO8601",     // 首次出现时间
  "last_updated": "ISO8601",   // 最近更新时间
  "status": "string",          // active|developing|stable|archived
  "topic": "string",           // 主类目 ID
  "importance": 0.0,           // 0-1
  "tracking_active": true,     // 是否持续跟踪
  "_schema_v": 1,              // [v2 新增] schema 版本号
  "keywords": ["string"],      // [v2 新增] 3-5 个关键词，用于快速匹配
  "item_ids": ["string"],      // 关联的 NewsItem ID 列表
  "timeline": [                // 时间线条目
    {
      "news_id": "string",
      "relation": "string",    // initial_report|follow_up|correction|analysis|community_reaction|test_result|patch|comparison|retraction
      "timestamp": "ISO8601",
      "brief": "string"        // 一句话描述这条时间线节点
    }
  ]
}
```

### 5.3 Source — 来源配置

```jsonc
{
  "id": "string",              // "src-" + kebab-case 名称
  "name": "string",            // 显示名称
  "type": "string",            // rss|github|search|social|official|community|topic_site|ranking
  "url": "string",             // 主 URL（RSS 地址、GitHub 仓库 URL 等）
  "weight": 1.0,               // 来源权重 0-2，默认 1.0
  "credibility": 0.8,          // 可信度 0-1，默认 0.8
  "topics": ["string"],        // 关联主题 ID 列表
  "enabled": true,
  "fetch_config": {            // 各类型特有的采集参数
    // RSS: { "format": "rss"|"atom" }
    // GitHub: { "repo": "owner/repo", "watch": "releases"|"commits"|"issues" }
    // Search: { "keywords": ["AI agent", "LLM"], "search_engine": "default" }
    // Ranking: { "selector": "CSS selector for items", "render": true }
  },
  "stats": {
    "total_fetched": 0,        // 历史采集总数
    "last_fetch": "ISO8601|null",
    "last_hit_count": 0,       // 上次采集命中条数
    "avg_daily_items": 0       // 日均产出
  }
}
```

### 5.4 UserPreference — 用户偏好（7 层模型）

```jsonc
{
  // 第 1 层：主题偏好
  "topic_weights": {
    "ai-models": 0.5,          // 冷启动默认 0.5（中性）
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
  "source_trust": {
    // "src-xxx": 0.9  — 按需填充，未配置的来源使用 Source.credibility 默认值
  },

  // 第 3 层：信息形态偏好
  "form_preference": {
    "release_note": 0.0,       // 冷启动默认 0.0（中性）
    "changelog": 0.0,
    "analysis": 0.0,
    "tutorial": 0.0,
    "opinion": 0.0,
    "news": 0.0,
    "announcement": 0.0,
    "clickbait": -0.3          // 预设负权重
  },

  // 第 4 层：深度偏好
  "depth_preference": "moderate",  // brief|moderate|detailed|technical

  // 第 5 层：判断角度偏好
  "judgment_angles": [
    // 冷启动为空，通过反馈学习填充
    // 可选值: workflow_impact, worth_trying, hype_vs_real, market_change, long_term_value, practical_use
  ],

  // 第 6 层：风格与容忍度
  "style": {
    "density": "medium",           // low|medium|high — 摘要密度
    "repetition_tolerance": "low", // low|medium|high — 重复事件容忍度
    "exploration_appetite": 0.3,   // 0-1，冷启动默认 0.3（较高探索） [v2 修正]
    "rumor_tolerance": "low"       // low|medium|high — 传闻类内容容忍度
  },

  // 第 7 层：样本反馈
  "feedback_samples": {
    "liked_items": [],             // 喜欢的 NewsItem ID 列表（最近 100 条）
    "disliked_items": [],          // 不喜欢的 NewsItem ID 列表（最近 100 条）
    "trusted_sources": [],         // 用户明确信任的 Source ID
    "distrusted_sources": [],      // 用户明确不信任的 Source ID
    "tracked_event_types": [],     // 用户明确要跟踪的事件类型关键词
    "blocked_patterns": []         // 用户明确不想看的内容模式描述
  },

  // 元数据
  "version": 1,
  "last_updated": "ISO8601",
  "last_decay_at": "ISO8601|null",  // [v2 新增] 上次衰减执行时间
  "total_feedback_count": 0
}
```

### 5.5 FeedbackEntry — 反馈条目 [v2 重写]

```jsonc
{
  "feedback_id": "string",     // 用户反馈："fb-" + SHA256(timestamp+type+target_id)[:12]
                                // 系统衰减："decay-" + YYYYMMDD-HHmmss
  "timestamp": "ISO8601",
  "type": "string",            // more|less|trust_source|distrust_source|track_event|
                                // block_pattern|like|dislike|adjust_style|system_decay|revert_feedback
  "target_type": "string",     // topic|source|news_item|event|form|style|preferences|feedback
  "target_id": "string",       // 目标 ID 或描述
  "value": "string"            // 用户原始反馈文本
}
```

注意：不包含 `applied` 字段。已应用状态由 `data/feedback/applied.json` 独立管理（§14.2）。

---

## 6. 存储与目录结构设计

### 6.1 工作空间目录结构

```text
<skill-workspace>/
├── SKILL.md                      # Skill 定义文件
├── config/
│   ├── sources.json              # 来源配置列表 — Source[]
│   ├── preferences.json          # 用户偏好 — UserPreference
│   └── categories.json           # 主题分类体系定义
├── data/
│   ├── news/
│   │   ├── YYYY-MM-DD.jsonl      # 按日存储 NewsItem（JSONL 格式，每行一条）
│   │   └── dedup-index.json      # 最近 7 天的 normalized_url SHA → news_id 映射
│   ├── events/
│   │   ├── active.json           # 当前活跃/developing 状态的 Event 列表
│   │   └── archive/
│   │       └── YYYY-MM.json      # 按月归档的已完结事件
│   └── feedback/
│       ├── log.jsonl             # 用户反馈日志 — FeedbackEntry（JSONL 追加写入，不可修改已有行）
│       ├── applied.json          # [v2 新增] 已应用反馈的权威账本（feedback_id → timestamp/"reverted"）
│       └── backup/               # [v2 新增] 偏好/账本/日志的自动备份
└── output/
    └── latest-digest.md          # 最近一次生成的输出（便于调试和回顾）
```

### 6.2 数据生命周期

| 数据类型 | 保留策略 | 说明 |
|---------|---------|------|
| NewsItem | 30 天 | 超过 30 天的 JSONL 文件可删除或归档 |
| dedup-index | 7 天滚动 | 仅保留最近 7 天的 URL 哈希，定期重建 |
| Event (active) | 直到 archived | status 变为 stable 后 7 天自动转为 archived |
| Event (archived) | 永久 | 按月归档，用于历史查询和周报 |
| Feedback log | 永久 | 追加写入，用于偏好分析 |
| Preferences | 永久 | 随反馈持续更新 |

### 6.3 容量估算

- 500+ 条/天 × 30 天 ≈ 15,000 条 NewsItem
- 每条 NewsItem 约 1KB（JSONL 行）→ 每日 ~500KB，月度 ~15MB
- dedup-index: 7 天 × 500 条 × 64 字节 ≈ 200KB
- 活跃事件: 通常 50-200 个 → < 1MB
- 整体工作空间: < 50MB / 月，完全可接受

### 6.4 Schema 兼容读取约定 [v2 新增]

- 每条记录含 `_schema_v` 标识版本
- 读取时：缺失字段用默认值推导，未知字段忽略
- JSONL 中允许不同版本记录共存，不回填历史数据

---

# 第三部分：功能模块设计

---

## 7. 来源管理

### 7.1 来源类型

系统支持以下来源类型，每种类型对应不同的采集工具和解析方式：

| 类型 ID | 名称 | 采集工具 | 解析方式 |
|---------|------|---------|---------|
| `rss` | RSS / Atom | `web_fetch` | 解析 XML，提取 title/link/description/pubDate |
| `github` | GitHub Release / Repo | `web_fetch` (GitHub API) | 解析 JSON，提取 release note / commit message |
| `official` | 官方公告 | `web_fetch` 或 `browser` | LLM 提取公告标题、内容、日期 |
| `search` | 搜索类 | `web_search` | 基于关键词搜索，LLM 过滤和摘要 |
| `community` | 社区 | `browser` | 渲染页面后 LLM 提取帖子/讨论 |
| `social` | 社交账号 | `web_fetch` 或 `browser` | LLM 提取动态，过滤噪声 |
| `topic_site` | 专题站点 | `browser` | 渲染后 LLM 提取文章列表 |
| `ranking` | 热门榜单 | `web_fetch` 或 `browser` | LLM 提取排名条目 |

### 7.2 来源管理能力

用户通过自然语言与 agent 交互管理来源：

- 添加来源：`"添加一个 RSS 来源：https://example.com/feed.xml，关注 AI 主题"`
- 删除来源：`"删除来源 xxx"`
- 启用/禁用：`"暂停采集 xxx"` / `"恢复 xxx"`
- 调整权重：`"提高 xxx 的权重"` / `"降低 xxx 的可信度"`
- 查看状态：`"列出所有来源"` / `"xxx 最近采集了什么"`

Skill 指令指导 agent 将这些操作映射到 `config/sources.json` 的读写。

### 7.3 来源扩展原则

**数据级扩展**（通过配置完成，不需要修改 Skill）：

- 新增一个 RSS 源
- 新增一个 GitHub 仓库
- 新增一个搜索关键词

**逻辑级扩展**（需要修改 Skill 指令）：

- 全新的来源类型（如 API 聚合平台）
- 特殊的解析/清洗逻辑（如财经数据的结构化提取）
- 需要认证的来源（如付费 API）

---

## 8. 新闻分类与主题体系

### 8.1 三层分类结构

```text
顶层类目（primary）→ 中层主题（secondary）→ 标签（tags）
```

### 8.2 顶层类目定义

`config/categories.json` 格式：

```jsonc
{
  "categories": [
    {
      "id": "ai-models",
      "name": "AI 与模型",
      "description": "大模型发布、评测、API、推理框架",
      "adjacent": ["dev-tools", "open-source", "science"]  // 邻近类目，用于防茧房
    },
    {
      "id": "dev-tools",
      "name": "软件开发与工具链",
      "description": "IDE、编辑器、构建工具、CI/CD、包管理器",
      "adjacent": ["ai-models", "open-source", "tech-products"]
    },
    {
      "id": "tech-products",
      "name": "科技产品与平台",
      "description": "硬件产品、云平台、SaaS、消费电子",
      "adjacent": ["dev-tools", "business"]
    },
    {
      "id": "business",
      "name": "商业与公司动态",
      "description": "融资、收购、裁员、战略调整、合作",
      "adjacent": ["tech-products", "finance"]
    },
    {
      "id": "finance",
      "name": "金融与市场",
      "description": "股市、加密货币、投资、经济指标",
      "adjacent": ["business", "macro-policy"]
    },
    {
      "id": "macro-policy",
      "name": "宏观与政策",
      "description": "政府政策、监管、法律法规、行业标准",
      "adjacent": ["finance", "international"]
    },
    {
      "id": "international",
      "name": "国际与地区新闻",
      "description": "地缘政治、国际关系、区域事件",
      "adjacent": ["macro-policy", "security"]
    },
    {
      "id": "security",
      "name": "安全与事故",
      "description": "安全漏洞、数据泄露、网络攻击、服务故障",
      "adjacent": ["dev-tools", "tech-products"]
    },
    {
      "id": "open-source",
      "name": "开源社区与开发者生态",
      "description": "开源项目、社区事件、许可证、贡献者动态",
      "adjacent": ["dev-tools", "ai-models"]
    },
    {
      "id": "gaming",
      "name": "游戏与数字娱乐",
      "description": "游戏发布、平台更新、电竞、流媒体",
      "adjacent": ["tech-products"]
    },
    {
      "id": "science",
      "name": "科学与研究",
      "description": "学术论文、研究突破、技术前沿",
      "adjacent": ["ai-models"]
    },
    {
      "id": "breaking",
      "name": "突发热点",
      "description": "不属于以上类别的重大突发事件",
      "adjacent": []
    }
  ]
}
```

### 8.3 分类规则

- 每条新闻由 LLM 进行多标签分类
- 必须指定一个 `primary` 类目
- 可选指定多个 `secondary` 类目
- 可选附加 `tags`（自由关键词，kebab-case）
- 一条新闻不限于单一分类，例如：AI 安全漏洞 → primary: `security`, secondary: `["ai-models"]`

---

## 9. 偏好系统

### 9.1 设计原则

偏好系统不能简化成"几个关键词 + 黑名单"。用户对新闻的喜好至少包含以下维度：

- 对什么主题感兴趣
- 对什么来源更信任
- 喜欢什么信息形态
- 喜欢多深的内容
- 用什么角度理解新闻
- 对不确定信息容忍度如何
- 是否喜欢追踪某类事件后续

因此偏好系统采用 **7 层模型**（数据结构见 §5.4 UserPreference）。

### 9.2 各层详解

**第 1 层：主题偏好**

表示用户大方向上更关注哪些领域。权重范围 0-1，0.5 为中性（冷启动默认）。

**第 2 层：来源信任**

不同用户对来源的信任不同。例如更信任官方公告、GitHub Release、开发者实测，对热搜榜保持保留。未配置的来源使用 `Source.credibility` 默认值。

**第 3 层：信息形态偏好**

用户偏好某种"内容形态"，如 release note、changelog、实测结果、工作流案例、争议点归纳。不喜欢标题党、空泛概念稿、纯市场宣传稿。

**第 4 层：深度偏好**

同一主题下信息深浅需求不同：
- `brief`: 只看结论
- `moderate`: 看一段摘要 + 为什么重要
- `detailed`: 看影响分析 + 是否值得跟进
- `technical`: 看技术细节与限制

**第 5 层：判断角度偏好**

用户最关心的判断角度，例如：是否影响工具链、是否值得试用、是否只是噱头、是否有落地价值。

**第 6 层：风格与容忍度**

系统输出的"脾气"：密度高低、重复容忍度、探索内容比例、传闻类内容处理方式。

**第 7 层：样本反馈**

存储用户明确表示过的喜恶样本。这层是偏好模型不断逼近真实用户兴趣的关键。

### 9.3 冷启动策略

首次使用时的初始化：

1. 所有 `topic_weights` 设为 `0.5`（中性，不偏不倚）
2. `exploration_appetite` 设为 `0.3`（较高探索，帮助发现兴趣）
3. `form_preference` 除 `clickbait: -0.3` 外全部为 `0.0`
4. `depth_preference` 设为 `"moderate"`
5. 其他层保持空或默认值

系统通过用户反馈逐步学习，无需初始问答流程。前几次输出会偏向均匀分布，随着反馈积累逐渐收敛到用户真实偏好。

### 9.4 新闻评分公式 [v2 重写]

对每条 NewsItem 计算最终分数：

```text
final_score = 
  importance_score × 0.25                    // 客观重要性 [0,1]
  + topic_weight(primary) × 0.20             // 主题匹配 [0,1]
  + source_trust(source_id) × 0.10           // 来源信任 [0,1]
  + form_preference_norm × 0.10              // 形态匹配，归一化到 [0,1]
  + feedback_boost × 0.10                    // 样本反馈加成 [0,1]
  + recency_score × 0.15                     // [v2 新增] 时效性 [0,1]
  + event_boost × 0.10                       // [v2 新增] 关联热门事件加成 [0,1]
```

**维度说明：**
- `form_preference_norm = (form_preference + 1) / 2`，将 [-1,1] 映射到 [0,1]
- `recency_score = max(0, 1 - hours_since_published / 48)` — 48 小时线性衰减
- `event_boost = 0.5` 如果关联事件 status == "active" 且 importance >= 0.7，否则 0
- `feedback_boost` 基于相似已点赞/踩的新闻计算

**边界规则：**
- `published_at` 缺失 → 使用 `fetched_at`，`recency_score` 额外 ×0.8（置信度折扣）
- `published_at` 在未来 → 按当前时间截断
- 关联热门活跃事件时，`event_boost` 部分抵消 recency 衰减
- 所有维度取值均 clamp 到 [0, 1]

---

## 10. 防茧房机制

### 10.1 设计原则

防茧房是系统的 **内建约束**，不是附加功能。

个性化不是为了把世界缩小到只剩舒适区，而是为了：

- 提高主兴趣命中率
- 同时保留外部世界的重要入口
- 保留跨领域高信号输入
- 保留一定的偶然发现能力

### 10.2 内容配额

| 配额层 | 日报比例 | 周报比例 | 说明 |
|--------|---------|---------|------|
| 核心兴趣 | 50% | 40% | topic_weight >= 0.7 的类目 |
| 邻近兴趣 | 20% | 20% | 核心类目的 `adjacent` 类目 |
| 公共热点 | 15% | 20% | importance_score >= 0.8 且不在核心/邻近范围 |
| 探索内容 | 15% | 20% | 其余类目中随机选取高质量内容 |

快讯不强调配比，只关注"高重要性"与"及时性"。

### 10.3 配额执行算法

```text
1. 从当日/当周候选新闻池中，按 final_score 降序排列
2. 将候选新闻按类目分组：core / adjacent / hotspot / explore
3. 根据输出类型（日报/周报）确定目标条数 N
4. 按配额比例从各组中取 top-K：
   - core_count = round(N × core_ratio)
   - adjacent_count = round(N × adjacent_ratio)
   - hotspot_count = round(N × hotspot_ratio)
   - explore_count = N - core_count - adjacent_count - hotspot_count
5. 配额不足时的让渡优先级 [v2 细化]：
   - explore 不足 → 让给 adjacent（保持多样性）
   - hotspot 不足 → 让给 core
   - adjacent 不足 → 让给 explore（不让给 core，避免加剧茧房）
   - core 不足 → adjacent → hotspot → explore
6. 合并结果，按时间倒序或重要性排序输出
```

### 10.4 反向多样性约束

当某一类内容连续多天占据过高比例时，系统自动轻度抑制：

- 同一主题连续 3 天占比 > 60% → 该主题本日配额上限降至 50%
- 同一来源连续 3 天占比 > 30% → 该来源本日配额上限降至 20%
- 同一事件连续推送 > 3 天 → 降低频率（仅在有新进展时推送）

### 10.5 热点注入规则

具有"跨主题重要性"的新闻，不应因偏好分低被完全挡掉：

- `importance_score >= 0.8` 的新闻强制进入候选池
- 重大安全事故、平台级服务故障、大规模政策变化等强制进入
- 热点也要经过质量判断、重复归并、与用户兴趣关系判断，不是原样搬运

### 10.6 偏好纠偏

当系统长期只收到同质反馈时，保留微量纠偏空间：

- 顶层类目最小覆盖：即使用户从不点击某类目，保留 ≥ 2% 的曝光
- 周报中的跨类重点：每期周报至少覆盖 5 个不同顶层类目
- 周期性多样性插入：每 7 天自动提升一次 `exploration_appetite`（+0.05，上限 0.4）[v2 修正：原上限 0.3 与初始值矛盾]

---

## 11. 去重与事件归并

### 11.1 三层去重策略

#### 第 1 层：链接级去重

在采集阶段立即执行，使用 `dedup-index.json` 快速判断：

**URL 规范化规则：**
- 去除 query 参数中的 `utm_*`、`ref`、`source`、`fbclid`、`gclid` 等追踪参数
- 统一 `http` → `https`
- 统一去除 `www.` 前缀
- 统一去除尾部 `/`
- 统一小写 host

```text
输入: https://www.example.com/article/123?utm_source=twitter&ref=homepage
规范化: https://example.com/article/123
SHA: sha256("https://example.com/article/123")[:16]
```

查询 `dedup-index.json`，如已存在则标记 `dedup_status: "url_dup"` 并跳过。

#### 第 2 层：标题近似去重（三阶段收缩）[v2 重写]

对通过精确去重的新闻执行：

**阶段 A：规则归一化**
- 去除标题中的标点、空格差异，统一大小写
- 去除常见前缀/后缀模式（"快讯："、"| xxx报道"）
- 生成 `normalized_title`

**阶段 B：Jaccard 相似度收缩**
- 对 normalized_title 做 bigram 分词
- 计算与最近 3 天标题的 Jaccard 相似度
- `similarity >= 0.6` 的标题对进入候选组
- 按来源+类目分组执行，避免跨域误匹配
- 预期：500 条/天 → 候选对缩减到 20-50 对

**阶段 C：LLM 精确判断**
- 仅对候选组执行 LLM 比较（批量模式，每组 ≤ 10 条标题）
- 预计每日 LLM 调用：5-15 次（非数千次两两比较）

判定为近似重复 → 写入 JSONL，标记 `dedup_status: "title_dup"`, `duplicate_of: "{主记录ID}"`。主记录：同组中来源可信度最高的那条。

**可选升级路线（Phase 2+，需确认环境支持）：**
- 引入 embedding 替代阶段 B，切换条件：候选对 > 100 或 Jaccard FP 率 > 20%

#### 第 3 层：事件级归并（分层筛选）[v2 重写]

**Step 1 — topic 预筛选：**
- 从 `data/events/active.json` 中筛选同 topic 的活跃事件（50-200 → 5-20）

**Step 2 — 关键词快速匹配：**
- 每个事件维护 `keywords[]`（3-5 个，创建/更新时 LLM 生成）
- 新闻标题与 keywords 做 token overlap，≥ 2 个匹配的进入候选

**Step 3 — LLM 精确归并：**
- 仅对候选事件（1-5 个）执行 LLM 判断
- Prompt 中只放候选事件 title + summary（≤ 500 tokens，不放全量列表）
- 归并 → 更新 Event 的 item_ids、timeline、last_updated、summary、keywords
- 无候选命中 → 创建新事件

### 11.2 Event 生命周期状态机

```text
                        有新关联新闻
        ┌──────────────────────┐
        │                      ▼
    [active] ──3天无更新──► [stable] ──7天无更新──► [archived]
        ▲                      │
        │                      │ 有新关联新闻
        │                      │
        └──────────────────────┘
                              
    新事件创建 → [active]
    重大变化（如反转/修正）→ 回到 [active]
```

状态转换条件：

| 当前状态 | 条件 | 目标状态 |
|---------|------|---------|
| active | 3 天内无新关联新闻 | stable |
| active | 有新关联新闻 | 保持 active，更新 last_updated |
| stable | 有新关联新闻 | 回到 active |
| stable | 7 天内无变化 | archived |
| archived | 有新关联新闻且 importance >= 0.7 | 回到 active |

---

## 12. 时间线追踪

### 12.1 目标

对于具有连续发展的新闻，系统能形成一条时间线，让用户看到的不是一组散乱标题，而是：

- 这件事从什么时候开始
- 现在进展到哪一步
- 过去几天发生了什么变化
- 是否值得继续关注

### 12.2 适用场景

- 新产品连续更新（发布 → 评测 → 争议 → 价格调整 → 补丁）
- 公司事件的多轮发展
- 政策变化的连续影响
- 安全事件的披露 → 扩散 → 修复 → 复盘
- 国际事件的阶段性变化

### 12.3 关系类型枚举

| 关系 ID | 名称 | 说明 |
|---------|------|------|
| `initial_report` | 首次报道 | 事件的第一条新闻 |
| `follow_up` | 后续更新 | 事件的新进展 |
| `correction` | 更正/辟谣 | 对之前报道的修正 |
| `analysis` | 分析解读 | 深度分析文章 |
| `community_reaction` | 社区反应 | 社区/用户的讨论和反馈 |
| `test_result` | 实测评测 | 具体的测试结果 |
| `patch` | 修复补丁 | 问题修复或版本更新 |
| `comparison` | 对比扩展 | 与其他产品/事件的对比 |
| `retraction` | 撤回/反转 | 事件出现重大反转 |

### 12.4 时间线展示格式

用于输出的 Markdown 模板：

```markdown
### 📌 {event.title}
**状态**: {status} | **重要性**: {importance} | **持续跟踪**: {tracking_active}

| 时间 | 进展 | 来源 |
|------|------|------|
| {timestamp} | 🆕 {brief} | {source_name} |
| {timestamp} | ⏩ {brief} | {source_name} |
| {timestamp} | 🔧 {brief} | {source_name} |

**当前状态摘要**: {event.summary}
```

---

## 13. 输出格式与内容生成

### 13.1 职责说明

本 Skill 只负责 **内容生成**。调度触发（何时运行）和推送投递（发到哪个渠道）由 OpenClaw cron + delivery 配置处理。

### 13.2 输出类型

| 输出类型 | 触发方式 | 内容特点 |
|---------|---------|---------|
| 日报 | cron 日报任务 | 过去一天的精选整理，按配额分配 |
| 晚报 | cron 晚报任务 | 半天增量，更短更精简 |
| 快讯 | cron 高频检查 | 仅在发现高重要性新闻时输出，无内容则不输出 |
| 周报 | cron 周报任务 | 回顾一周趋势，含事件时间线和跨领域总结 |
| 专题追踪 | 用户请求或 cron | 围绕某个主题或事件的深度追踪 |

### 13.3 输出模板

**日报模板：**

```markdown
# 📰 新闻日报 — {date}

## 核心关注
{对每条核心兴趣新闻：标题 + 2-3 句摘要 + 来源 + 重要性}

## 相关动态
{邻近兴趣新闻，更简短}

## 今日热点
{公共热点新闻}

## 探索发现
{探索类内容，附带"为什么推荐这条"的一句解释}

## 事件跟踪
{活跃事件的时间线更新，仅显示有新进展的事件}

---
来源: {source_count} 个来源 | 处理: {total_items} 条 | 精选: {selected_items} 条
```

**快讯模板：**

```markdown
🚨 **快讯** — {timestamp}

**{title}**
{2-3 句摘要}

重要性: {importance}/10 | 来源: {source_name}
{如有关联事件: "关联事件: {event.title}"}
```

**周报模板：**

```markdown
# 📊 新闻周报 — {week_range}

## 本周要点
{3-5 条最重要的新闻/事件概述}

## 趋势观察
{跨领域趋势分析}

## 重点事件时间线
{本周有进展的事件时间线}

## 各领域速览
{按类目分组的简要列表}

## 探索推荐
{本周值得关注但可能被忽略的内容}
```

### 13.4 输出控制参数

Skill 指令中定义的可调参数（通过自然语言调整）：

| 参数 | 默认值 | 说明 |
|------|-------|------|
| 日报条数 | 15-25 | 精选条目数量 |
| 周报条数 | 30-50 | 精选条目数量 |
| 快讯阈值 | importance >= 0.85 | 触发快讯的最低重要性 |
| 摘要长度 | 2-3 句 | 每条新闻的摘要长度 |
| 时间线显示 | 仅有更新的事件 | 是否在日报中显示时间线 |
| 探索内容 | 开启 | 是否包含探索类推荐 |
| 空输出策略 | 快讯不输出，日报至少输出 | 无内容时的行为 |

---

## 14. 反馈学习与历史查询

### 14.1 反馈类型与偏好影响映射

| 反馈类型 | 用户说法示例 | 影响的偏好字段 | 调整方式 |
|---------|------------|--------------|---------|
| `more` | "以后这类多推" | `topic_weights` | 目标类目 +0.1 |
| `less` | "以后这类少推" | `topic_weights` | 目标类目 -0.1 |
| `trust_source` | "这个来源质量高" | `source_trust` / `feedback_samples.trusted_sources` | 来源信任 +0.15，加入信任列表 |
| `distrust_source` | "这个来源以后降权" | `source_trust` / `feedback_samples.distrusted_sources` | 来源信任 -0.2，加入不信任列表 |
| `like` | "这条不错" | `feedback_samples.liked_items` | 记录样本，同时微调相关偏好 |
| `dislike` | "这条不想看" | `feedback_samples.disliked_items` | 记录样本，同时微调相关偏好 |
| `track_event` | "这个事件继续跟踪" | Event.tracking_active | 强制保持 active 状态 |
| `block_pattern` | "这种标题党不要" | `form_preference` / `feedback_samples.blocked_patterns` | 相关形态 -0.2，记录模式 |
| `adjust_style` | "最近热点可以多一点" | `style.exploration_appetite` | 直接调整风格参数 |

### 14.2 偏好更新规则 [v2 重写]

#### 14.2.1 增量应用（日常运行路径）

每次采集/生成任务运行时执行：

1. **加载状态**：读取 preferences.json + applied.json + log.jsonl
2. **筛选待应用反馈**：遍历 log，查 applied.json（唯一权威账本）。已存在 → 跳过。遇到 `revert_feedback` 且未处理 → 立即切换全量重建
3. **内存计算**：复制 preferences → preferences_next，按时间顺序应用待应用反馈
4. **原子批量提交**：写 preferences.json.tmp + applied.json.tmp → 验证 → 两个 rename
5. **清理**：删除 tmp 文件

**崩溃恢复**：两个 tmp 都在 → 重走增量；仅一个 rename 完成 → 触发全量重建

#### 14.2.2 全量重建（修复/审计路径）

1. **预扫描撤销**：收集 log 中所有 `revert_feedback` 的 target_id 为 `reverted_ids`
2. **初始化**：preferences 重置为冷启动默认值，忽略旧 applied.json
3. **回放**：按 timestamp 排序（同 timestamp: system_decay 先于用户反馈，同类按 feedback_id 字典序）。feedback_id in reverted_ids → 跳过；type == revert_feedback → 跳过；其他 → 应用
4. **原子提交**：同增量路径 Step 4

**一致性保证**：增量和全量对相同 log 产生相同偏好状态

#### 14.2.3 偏好衰减（可重放协议）

衰减是显式系统事件，写入 log.jsonl，与用户反馈共享统一时间线。

**触发规则**：每次增量运行检查 `last_decay_at`，距今 ≥ 30 天 → 生成 `system_decay` 事件

**Catch-up 算法**：从 `last_decay_at + 30d` 开始循环，每跨过完整 30 天窗口追加 1 条 system_decay（timestamp = 窗口边界），直到 next_decay_at > run_started_at

**衰减执行**：`w_new = w + (0.5 - w) × 0.05`（向均值回归 5%）

#### 14.2.4 反馈撤销协议（append-only 补偿）

不得删除或修改 log.jsonl 已有行，不得在增量路径中反向应用。

撤销方式：追加 `revert_feedback` 标记 → 强制全量重建（§14.2.2 跳过被撤销事件）

#### 14.2.5 权重调整范围

- 单次反馈：±0.05 ~ ±0.2
- 上下限：topic_weights [0, 1]，source_trust [0, 1]，form_preference [-1, 1]
- 大幅调整（单次 > 0.3）→ 升级确认（见 Standing Orders）

#### 14.2.6 运行态回滚

- **自动备份**：每次偏好更新前备份 preferences.json + applied.json + log.jsonl（保留最近 10 个）
- **Kill Switch**：preferences.json 中 `feedback_processing_enabled: false` 冻结偏好
- **恢复步骤**：止血(kill switch) → 诊断 → 追加 revert_feedback 补偿 → 全量重建 → 验证 → 恢复处理

### 14.3 历史查询能力

用户可以通过自然语言向 agent 查询：

| 查询类型 | 示例 | 数据源 |
|---------|------|--------|
| 最近动态 | "最近 24 小时有什么值得看" | `data/news/YYYY-MM-DD.jsonl` |
| 主题回顾 | "AI 模型这周有什么新进展" | 按 categories 过滤 news |
| 事件跟踪 | "Claude 4 发布后续怎样了" | `data/events/active.json` |
| 热点扫描 | "最近有哪些高热但不在我偏好里的" | 按 importance 过滤 + 偏好交叉 |
| 时间线 | "给我做个某事件的时间线" | Event.timeline |
| 来源分析 | "某个来源最近都在推什么" | 按 source_id 过滤 news |
| 趋势总结 | "某类主题的阶段性总结" | 跨日聚合 + LLM 总结 |

Skill 指令指导 agent 如何根据用户查询意图，定位到对应的数据文件，读取并用 LLM 生成结构化回答。

### 14.4 反馈引用消歧规则 [v2 新增]

当用户反馈指向某条具体新闻时，按以下优先级消歧：

1. **消息回复关联**：用户回复了某条推送消息 → 直接关联 news_id
2. **序号引用**：用户说"第 N 条" → 映射到最近一次输出的第 N 条
3. **关键词搜索**：用户说"关于 xxx 的那条" → 在最近 24h 新闻中搜索
4. **事件引用**：用户说"xxx 事件" → 匹配活跃事件标题
5. **无法消歧** → 向用户确认，列出 2-3 个候选

---

# 第四部分：执行路线

---

## 15. 设计原则与反模式

### 15.1 应遵循的原则

1. **系统级而非插件级** — 一个统一的 Skill 编排所有功能，不拆碎成多个 micro-skill
2. **多维偏好而非关键词过滤** — 7 层模型，不是简单的"关键词 + 黑名单"
3. **内建约束而非附加功能** — 防茧房是核心设计约束，不是可选插件
4. **事件级而非链接级** — 新闻处理上升到事件维度，不停留在逐条处理
5. **平台能力复用** — 调度、推送、采集触发利用 OpenClaw 原生能力，不重复造轮子

### 15.2 应避免的反模式

1. **不要把偏好理解成"尽量少给用户意外"** — 好的个性化是大部分命中兴趣 + 少量打开新视角 + 重大变化不被屏蔽
2. **不要把热点理解成"热搜榜原样搬运"** — 热点也要经过质量判断、重复归并、重要性识别
3. **不要把时间线理解成"按时间倒序堆标题"** — 真正的时间线应体现新阶段、补充、反转、修复、衰退
4. **不要把来源扩展做成无限拆碎的 Skill 列表** — 新来源通过配置添加，只有全新类型才需要修改 Skill

---

## 16. MVP 定义与分阶段路线图

### Phase 0 — 最小可用版本 [v2 拆分为三子阶段]

#### Phase 0A — 骨架搭建

**目标**: 创建完整 Skill 框架和配置文件

**交付物**: 完整目录结构 + SKILL.md 框架 + categories.json + preferences.json（冷启动）+ sources.json（1 个 RSS）

**完成标准**: 目录正确，配置文件 JSON 合法，SKILL.md frontmatter 合规

#### Phase 0B — 单来源采集验证

**目标**: 能从 1 个 RSS 来源采集新闻并持久化

**新增能力**: RSS 采集指令 + 链接去重 + NewsItem 基础字段 + 原子写入

**完成标准**: 手动触发采集写入 JSONL，重复触发无重复记录（幂等验证）

**集成验证**: 触发 → 采集 → 写入 → 再次触发 → 无重复

#### Phase 0C — 日报生成

**目标**: 从采集数据生成有分类的日报

**新增能力**: LLM 分类 + 摘要生成 + 基础评分排序 + 日报 Markdown 生成

**完成标准**: 日报有分类标签、摘要、来源标注、评分排序。空输入不生成空日报

**集成验证**: 采集 → 去重 → 分类/摘要 → 评分 → 日报，端到端跑通

### Phase 1 — 基础系统

**目标**: 多来源类型 + 偏好管理 + 基础反馈循环。

**新增能力**:
- 支持 GitHub、搜索、网页等来源类型
- 来源管理（自然语言增删改查）
- 基础偏好系统（主题权重 + 来源信任 + 形态偏好）
- 基础反馈处理（多推/少推/信任/降权）
- 晚报和快讯输出类型

**完成标准**:
- 支持 ≥ 3 种来源类型的采集
- 用户反馈能影响后续输出排序
- 快讯能在高重要性事件时触发

**集成验证** [v2 新增]: 用户添加来源 → 采集 → 反馈"多推" → 下次日报排序变化

**数据迁移** [v2 新增]: 已有 NewsItem 补 `_schema_v: 1`，新增字段为 null 不回填

### Phase 2 — 智能处理

**目标**: 事件级处理 + 时间线 + 防茧房。

**新增能力**:
- 标题近似去重（LLM）
- 事件归并 + Event 生命周期管理
- 时间线追踪
- 防茧房配额机制
- 反向多样性约束

**完成标准**:
- 同一事件的多条新闻合并为一个事件展示
- 日报中可观察到配额比例分布（核心/邻近/热点/探索）
- 持续发展的事件有时间线视图

**集成验证** [v2 新增]: 同一事件 3 条不同来源 → 归并 → 日报显示时间线；配额比例可观测

**数据迁移** [v2 新增]: 已有 Event 补 `keywords: []` 和 `_schema_v: 1`，首次运行 LLM 生成 keywords

### Phase 3 — 闭环系统

**目标**: 完整的反馈闭环 + 历史查询 + 研究能力。

**新增能力**:
- 完整的 7 层偏好模型
- 偏好衰减与纠偏机制
- 周报输出（含趋势分析）
- 历史查询（自然语言查询数据）
- 专题追踪输出
- 研究导向总结（阶段性回顾、趋势观察）

**完成标准**:
- 用户反馈完整影响所有 7 层偏好
- 偏好不会极端固化（衰减机制有效）
- 支持自然语言查询历史新闻和事件
- 周报覆盖 ≥ 5 个不同类目

**集成验证** [v2 新增]: 连续 7 天反馈 → 偏好变化可观测；30 天后衰减生效；自然语言查询可用

**数据迁移** [v2 新增]: 启用 applied.json 账本，feedback log 中旧记录按 feedback_id 回填
