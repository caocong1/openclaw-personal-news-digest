# OpenClaw 个性化新闻系统 (news-digest)

## What This Is

一个基于 OpenClaw 平台的个性化新闻研究与推送 Skill。它运行在 OpenClaw Agent 内部，利用平台原生工具链（采集、调度、推送、存储）完成新闻编排任务。系统具备多来源采集（RSS、GitHub、搜索、官方公告、社区、榜单）、LLM 驱动的分类/摘要/去重、事件归并与时间线追踪、7 层偏好模型、防茧房配额机制、反馈学习闭环、成本控制与监控、以及自然语言历史查询能力。

## Core Value

能从"给用户推消息"升级为"替用户持续观察世界中他关心的部分"——在深度个性化的同时，通过防茧房机制保留对外部世界重要入口的感知。

## Requirements

### Validated

- ✓ Skill 框架搭建（SKILL.md + references/ + scripts/ + config/）— v1.0
- ✓ 多来源新闻采集（6 种类型）与自然语言管理 — v1.0
- ✓ LLM 驱动的多标签主题分类（12 个顶层类目）— v1.0
- ✓ LLM 摘要生成（中文输出，多语言处理）— v1.0
- ✓ 三层去重策略（链接级、标题近似、事件级归并）— v1.0
- ✓ 事件归并与时间线追踪（active → stable → archived 生命周期）— v1.0
- ✓ 7 层用户偏好模型（含 depth_preference + judgment_angles）— v1.0
- ✓ 7 维个性化评分公式 — v1.0
- ✓ 防茧房配额机制（核心 50% / 邻近 20% / 热点 15% / 探索 15%）— v1.0
- ✓ 日报、快讯、周报三种输出类型 — v1.0
- ✓ 反馈学习系统（8 种反馈类型 → 偏好增量更新）— v1.0
- ✓ LLM 成本预算与熔断机制 — v1.0
- ✓ LLM 结果缓存层 — v1.0
- ✓ 监控与可观测性（健康指标、告警、巡检、per_source metrics）— v1.0
- ✓ 自然语言历史查询（5 种查询类型）— v1.0
- ✓ 偏好衰减机制（向均值回归）— v1.0
- ✓ 来源自动降级与恢复（端到端 per-source metrics 驱动）— v1.0
- ✓ 日报深度偏好端对端贯通 — v1.0
- ✓ 全输出中文化 + 渲染契约（用户字段 vs 内部字段分离）— v2.0 Phase 8
- ✓ 缓存版本控制（prompt_version 驱动缓存失效）— v2.0 Phase 8
- ✓ 写入前质量契约（UTF-8 清洗、标题/URL/ID 校验）— v2.0 Phase 8
- ✓ 引导启动验证 + 确定性测试夹具（8 个场景文件）— v2.0 Phase 8
- ✓ 噪声过滤（预分类模式匹配 + 分类后重要性阈值）— v2.0 Phase 9
- ✓ 分类提示词强化（低端校准、消歧规则、反例）— v2.0 Phase 9
- ✓ 快讯状态持久化与统一决策树（AlertState + 3-alert daily cap + URL dedup）— v2.0 Phase 10
- ✓ 事件级快讯记忆与增量快讯（Event v3 alert memory + delta alerts）— v2.0 Phase 10
- ✓ 跨日报重复惩罚（DigestHistory + 0.7x repetition penalty + suppression footer）— v2.0 Phase 10
- ✓ 可观测性完整贯通（透明度底部准确来源计数 + 失败来源标注 + run_log 结构化日志 + Schema Version Registry + diagnostics.sh）— v2.0 Phase 11

### Active

#### Current Milestone: v2.0 Quality & Robustness

**Goal:** Address all 27+ improvement items (IMPROVEMENTS.md) through output localization, noise filtering, dedup hardening, observability, and interaction UX improvements.

**Target features:**
- Full output localization (all labels → Chinese)
- Text cleanliness & cache versioning infrastructure
- Noise floor filtering (pre-classify + post-classify)
- Classification quality improvements
- Alert state & event memory (daily cap + per-event dedup + delta alerts)
- Cross-digest repetition control
- Observability integrity (run_log, schema registry, diagnostics) ✓
- Deployment UX (scheduling profiles, source visibility)
- Interaction explainability & rolling coverage

### Out of Scope

- Embedding 替代 Jaccard — 当前规模不需要额外依赖
- 反馈撤销 + 全量重建 — 手动修改已够用
- A/B 测试框架 — 单用户场景无对照组
- 多用户支持 — 架构变动大，延后到 V2
- 情感分析 — 优先级低
- 热点预测 — 数据积累不足
- 来源自动发现 — 需充分用户反馈数据
- SQLite 迁移 — 30 天 JSONL 性能可接受，按需再考虑
- 实时聊天/视频内容 — 复杂度高，非核心价值
- 移动端应用 — Web/聊天渠道优先

## Context

**Shipped v1.0** with ~45,400 lines across 100 files (Markdown skill documents).
Tech stack: OpenClaw Skill (SKILL.md + references/ + scripts/ + config/), JSONL storage, LLM-driven processing.
7 phases delivered: MVP Pipeline, Multi-Source + Preferences, Smart Processing, Closed Loop, Integration Wiring Fixes, Daily Depth Control Wiring, Per-Source Metrics Continuity.

**平台环境**：OpenClaw AI Agent 平台（https://openclaw.ai/），Skill 以 SKILL.md + 引用文档 + 辅助脚本的形式运行在 Agent 内部。

**可用工具**：web_fetch, browser, web_search, read/write, cron, message + delivery, exec

**设计规格来源**：gpt-plan-v3.md — 经过 6 个 AI 模型独立评审优化的完整设计文档。

**Live platform verification pending:** cron delivery, isolated session, exec permission, timeout, dedup, and empty-input quality gate need real platform testing.

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
| SKILL.md 模块化拆分 | 6/6 评审共识：避免巨型指令文件降低 agent 执行一致性 | ✓ Good |
| 偏好模型 5→7 层 | MVP 收缩后在 Phase 3 扩展 depth_preference + judgment_angles | ✓ Good |
| form_type 5 种（非 7 种） | Claude Opus 评审：过细枚举分类收益低于复杂度代价 | ✓ Good |
| 时间线关系 5 种（非 9 种） | 4/6 评审建议，由 brief 字段承载细粒度描述 | ✓ Good |
| 事件状态 3 态（非 4 态） | developing 与 active 语义重叠，简化为三态 | ✓ Good |
| 输出类型 3 种（非 5 种） | 晚报/专题可用现有能力替代 | ✓ Good |
| 简化锁机制为获取失败即跳过 | 4/6 评审：单用户低并发场景足够 | ✓ Good |
| 取消反馈全量重建和撤销协议 | 5/6 评审：MVP 实现成本远大于收益 | ✓ Good |
| Phase 0 合并为单阶段 | Qwen 评审：三子阶段紧耦合，拆分增加管理开销 | ✓ Good |
| Milestone audit → gap phases (5+6) | Audit found 5 partial REQs; targeted phases closed all gaps | ✓ Good |
| per_source DailyMetrics contract | Enables source health, monitoring, degrade/recover end-to-end | ✓ Good |

---
## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):
1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-02 after Phase 11 (Observability & Data Integrity) — run_log, Schema Version Registry, diagnostics.sh, failed source footer, source_count accuracy*
