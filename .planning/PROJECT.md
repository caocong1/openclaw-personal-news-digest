# OpenClaw 个性化新闻系统 (news-digest)

## What This Is

一个基于 OpenClaw 平台的个性化新闻研究与推送 Skill。它运行在 OpenClaw Agent 内部，利用平台原生工具链（采集、调度、推送、存储）完成新闻编排任务。系统具备多来源采集、LLM 驱动的分类/摘要/去重、事件归并与时间线追踪、5 层偏好模型、防茧房机制，以及成本控制与监控能力。

## Core Value

能从"给用户推消息"升级为"替用户持续观察世界中他关心的部分"——在深度个性化的同时，通过防茧房机制保留对外部世界重要入口的感知。

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] 多来源新闻采集（RSS、GitHub、搜索、官方公告、社区、榜单）
- [ ] LLM 驱动的多标签主题分类（12 个顶层类目）
- [ ] LLM 驱动的新闻摘要生成（中文输出）
- [ ] 三层去重策略（链接级、标题近似、事件级归并）
- [ ] 事件归并与时间线追踪（active → stable → archived 生命周期）
- [ ] 5 层用户偏好模型（主题、来源信任、形态、风格、样本反馈）
- [ ] 个性化评分公式（7 维加权）
- [ ] 防茧房配额机制（核心 50% / 邻近 20% / 热点 15% / 探索 15%）
- [ ] 日报、快讯、周报三种输出类型
- [ ] 反馈学习系统（8 种反馈类型 → 偏好增量更新）
- [ ] LLM 成本预算与熔断机制
- [ ] LLM 结果缓存层
- [ ] 来源健康度动态评估与自动降级/恢复
- [ ] 监控与可观测性（健康指标、告警、巡检）
- [ ] 多语言处理（中文 + 英文，统一中文摘要输出）
- [ ] 自然语言历史查询
- [ ] 偏好衰减机制（向均值回归）
- [ ] 隐私合规基础约定

### Out of Scope

- Embedding 替代 Jaccard — 当前规模不需要额外依赖，延后到 Phase 4+
- 反馈撤销 + 全量重建 — 手动修改已够用，延后到 Phase 4+
- A/B 测试框架 — 单用户场景无对照组
- 多用户支持 — 架构变动大，延后到 V2
- 情感分析 — 优先级低，延后到 Phase 4+
- 热点预测 — 数据积累不足，延后到 Phase 4+
- 来源自动发现 — 需充分用户反馈数据，延后到 Phase 3+
- SQLite 迁移 — 30 天 JSONL 性能可接受，按需再考虑
- 实时聊天/视频内容 — 复杂度高，非核心价值
- 移动端应用 — Web/聊天渠道优先

## Context

**平台环境**：OpenClaw AI Agent 平台（https://openclaw.ai/），Skill 以 SKILL.md + 引用文档 + 辅助脚本的形式运行在 Agent 内部。

**可用工具**：
- `web_fetch` — RSS/API 采集
- `browser` — 需要渲染的网页抓取
- `web_search` — 关键词搜索
- `read` / `write` — 工作空间文件读写
- `cron` — 定时调度触发
- `message` + cron `delivery` — 内容推送到聊天渠道
- `exec` — 辅助脚本执行（待验证）

**设计规格来源**：gpt-plan-v3.md — 经过 6 个 AI 模型（Claude Opus、GPT-5.4、Qwen、GLM-5、MiniMax、Kimi）独立评审优化的完整设计文档。

**关键设计决策**：
- SKILL.md 模块化拆分（< 3000 tokens），详细规范拆到 references/
- 分步执行 + 按需加载上下文窗口管理策略
- 文件锁互斥（获取失败即跳过）
- JSONL 按日分文件存储
- Schema 版本化兼容读取

**平台能力待验证**（Phase 0）：
- isolated session 可访问工作空间文件
- `exec` 可执行辅助脚本
- `browser` 可稳定抓取渲染页面
- cron `delivery` 支持多渠道投递
- 单次 agent turn 超时 ≥ 10 分钟

## Constraints

- **平台约束**: 必须作为 OpenClaw Skill 运行，不能是独立后端服务
- **上下文窗口**: SKILL.md < 3000 tokens，分步执行避免上下文压力
- **成本控制**: 日均 LLM 调用预算 500 次 / 1M tokens，超 80% 告警，100% 熔断
- **存储**: 工作空间文件系统，无数据库，JSONL + JSON 存储
- **单用户**: MVP 阶段单用户设计，不考虑多租户
- **数据合规**: 不存原文全文，尊重 robots.txt，摘要为 LLM 改写

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| SKILL.md 模块化拆分 | 6/6 评审共识：避免巨型指令文件降低 agent 执行一致性 | — Pending |
| 偏好模型 5 层（非 7 层） | GPT-5.4 建议 MVP 收缩复杂度，保留扩展接口 | — Pending |
| form_type 5 种（非 7 种） | Claude Opus 评审：过细枚举分类收益低于复杂度代价 | — Pending |
| 时间线关系 5 种（非 9 种） | 4/6 评审建议，由 brief 字段承载细粒度描述 | — Pending |
| 事件状态 3 态（非 4 态） | developing 与 active 语义重叠，简化为三态 | — Pending |
| 输出类型 3 种（非 5 种） | 晚报/专题可用现有能力替代 | — Pending |
| 简化锁机制为获取失败即跳过 | 4/6 评审：单用户低并发场景足够 | — Pending |
| 取消反馈全量重建和撤销协议 | 5/6 评审：MVP 实现成本远大于收益 | — Pending |
| Phase 0 合并为单阶段 | Qwen 评审：三子阶段紧耦合，拆分增加管理开销 | — Pending |

---
*Last updated: 2026-03-31 after initialization*
