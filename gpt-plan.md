# OpenClaw 个性化新闻系统计划文档

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
  "dedup_status": "string"     // unique|url_dup|title_dup|event_merged
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
    "exploration_appetite": 0.15,  // 0-1，冷启动默认 0.3（较高探索）
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
  "total_feedback_count": 0
}
```

### 5.5 FeedbackEntry — 反馈条目

```jsonc
{
  "timestamp": "ISO8601",
  "type": "string",            // more|less|trust_source|distrust_source|track_event|block_pattern|like|dislike|adjust_style
  "target_type": "string",     // topic|source|news_item|event|form|style
  "target_id": "string",       // 目标 ID 或描述
  "value": "string",           // 用户原始反馈文本
  "applied": true              // 是否已应用到偏好
}
```

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
│       └── log.jsonl             # 用户反馈日志 — FeedbackEntry（JSONL 追加写入）
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

### 9.4 新闻评分公式

对每条 NewsItem 计算最终分数，用于排序和筛选：

```text
final_score = 
  importance_score × 0.3                          // 客观重要性
  + topic_weight(primary) × 0.25                   // 主题匹配
  + source_trust(source_id) × 0.15                 // 来源信任
  + form_preference(form_type) × 0.15              // 形态匹配
  + feedback_boost × 0.15                          // 样本反馈加成
```

其中 `feedback_boost` 基于相似已点赞/踩的新闻计算。

权重可随系统成熟度调整，此处为初始建议值。

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
5. 如某组候选不足，将配额让给相邻组
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
- 周期性多样性插入：每 7 天自动提升一次 `exploration_appetite`（+0.05，上限 0.3）

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

#### 第 2 层：标题近似去重

对通过链接去重的新闻，使用 LLM 判断标题是否描述同一事件：

```text
Prompt: 以下两条新闻标题是否在描述同一件事？只回答 yes 或 no。
标题 A: {title_a}
标题 B: {title_b}
```

由于 LLM 调用不限制，可对当日所有新标题两两比较（或与最近 3 天标题比较）。对于 500+/天的量级，可先用来源+类目分组缩小比较范围。

标记 `dedup_status: "title_dup"`，保留质量更高（来源可信度更高）的那条。

#### 第 3 层：事件级归并

对去重后的新闻，判断是否属于已有活跃事件：

```text
Prompt: 以下新闻是否属于某个已知事件？如果是，返回事件 ID；如果是新事件，返回 "new"。

新闻标题: {title}
新闻摘要: {summary}

活跃事件列表:
{events_list}  // 每个事件的 title + summary
```

归并后更新 Event 的 `item_ids`、`timeline`、`last_updated`、`summary`。

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
**状态**: {status} | **重要性**: {importance}/10 | **持续跟踪**: {tracking_active}

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

### 14.2 偏好更新规则

- 单次反馈权重调整范围：±0.05 ~ ±0.2（根据反馈强度）
- 权重上下限：topic_weights [0, 1]，source_trust [0, 1]，form_preference [-1, 1]
- 衰减策略：每 30 天对所有权重做轻微回归均值（向 0.5 方向移动 5%），避免极端固化
- 大幅调整（单次 > 0.3）需要升级确认（见 Standing Orders）

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

### Phase 0 — 最小可用版本

**目标**: 能采集 RSS 来源，生成一份有分类的日报。

**交付物**:
- `SKILL.md` 完整定义
- `config/sources.json` 含 3-5 个 RSS 来源
- `config/categories.json` 分类体系
- `config/preferences.json` 冷启动默认偏好
- 基础目录结构

**能力**:
- 采集 RSS 来源（`web_fetch` + LLM 解析）
- LLM 分类和摘要生成
- 链接级去重（`dedup-index.json`）
- 生成日报 Markdown（按 final_score 排序）
- 输出到 `output/latest-digest.md`

**完成标准**:
- 通过 cron 触发 agent，能自动采集并输出一份包含分类的日报
- 日报内容有摘要、有分类标签、有来源标注

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
