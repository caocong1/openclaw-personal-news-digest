# Requirements: OpenClaw 个性化新闻系统 (news-digest)

**Defined:** 2026-03-31
**Core Value:** 替用户持续观察世界中他关心的部分——深度个性化的同时保留外部世界重要入口

## v1 Requirements

Requirements for Phase 0-3 delivery. Each maps to roadmap phases.

### Skill Framework

- [x] **FRMW-01**: Skill 目录结构完整搭建（SKILL.md + references/ + scripts/ + config/ + data/ + output/）
- [x] **FRMW-02**: SKILL.md 模块化编排（< 3000 tokens），详细规范拆分到 references/
- [x] **FRMW-03**: Standing Orders 定义（授权范围、升级条件、禁止事项）
- [x] **FRMW-04**: 文件锁互斥机制（获取失败即跳过，15 分钟过期）
- [x] **FRMW-05**: 原子写入（tmp + rename 模式，崩溃恢复清理 > 15min 的临时文件）
- [x] **FRMW-06**: Schema 版本化兼容读取（_schema_v 字段，缺失字段默认值推导）

### Source Management

- [x] **SRC-01**: RSS/Atom feed 采集（web_fetch 解析 XML，提取 title/link/description/pubDate）
- [x] **SRC-02**: GitHub Release/Repo 采集（GitHub API JSON 解析）
- [x] **SRC-03**: 搜索类来源采集（web_search 关键词搜索 + LLM 过滤）
- [x] **SRC-04**: 官方公告采集（web_fetch 或 browser + LLM 提取）
- [x] **SRC-05**: 社区页面采集（browser 渲染 + LLM 提取）
- [x] **SRC-06**: 热门榜单采集（web_fetch 或 browser + LLM 提取排名条目）
- [x] **SRC-07**: 自然语言来源管理（添加/删除/启用/禁用/调权重，删除需二次确认）
- [x] **SRC-08**: 来源健康度指标（quality_score / dedup_rate / selection_rate 自动计算）
- [ ] **SRC-09**: 来源自动降级与恢复（quality_score < 0.2 连续 14 天降级，> 0.3 连续 7 天恢复）
- [x] **SRC-10**: 输入歧义处理（多义操作追问确认，相似来源列候选）

### Content Processing

- [x] **PROC-01**: URL 规范化 + 链接级去重（去追踪参数 → SHA256[:16] → dedup-index 查询）
- [x] **PROC-02**: LLM 多标签分类（12 个顶层类目 + 细粒度 tags + importance_score + form_type）
- [x] **PROC-03**: LLM 摘要生成（2-3 句中文摘要，非中文新闻标题保留原文附中文翻译）
- [x] **PROC-04**: 标题近似去重三阶段（规则归一化 → Jaccard bigram ≥ 0.6 → LLM 精确判断）
- [x] **PROC-05**: 批量 LLM 处理（分类和摘要 5-10 条/次，减少 per-call overhead）
- [x] **PROC-06**: 多语言处理（中文 + 英文，不同语言独立去重，允许跨语言事件归并）
- [x] **PROC-07**: 容错处理（分类失败但摘要成功 → 归入探索位；LLM 格式异常 → 重试 1 次）
- [x] **PROC-08**: 断点续跑（processing_status: "raw" 的记录下次运行补充分类/摘要）

### Event Tracking

- [x] **EVT-01**: 事件归并（topic 预筛选 → 关键词快速匹配 → LLM 精确归并）
- [x] **EVT-02**: 事件生命周期（active → 3 天无更新 → stable → 7 天无更新 → archived）
- [x] **EVT-03**: 时间线追踪（5 种关系类型：initial/update/correction/analysis/reversal）
- [x] **EVT-04**: 事件摘要随新关联新闻自动更新
- [x] **EVT-05**: 时间线 bullet list 格式展示（兼容聊天渠道）

### Preference System

- [x] **PREF-01**: 5 层偏好模型（主题权重 + 来源信任 + 形态偏好 + 风格容忍度 + 样本反馈）
- [x] **PREF-02**: 冷启动策略（所有 topic_weights = 0.5，exploration_appetite = 0.3，无初始问卷）
- [x] **PREF-03**: 7 维个性化评分公式（importance × 0.25 + topic × 0.20 + source × 0.10 + form × 0.10 + feedback × 0.10 + recency × 0.15 + event × 0.10）
- [ ] **PREF-04**: 偏好衰减（每 30 天向均值回归 5%：w_new = w + (0.5 - w) × 0.05）
- [x] **PREF-05**: 偏好自动备份（更新前备份，保留最近 10 个）
- [ ] **PREF-06**: 偏好可视化（文字化描述当前偏好状态）
- [ ] **PREF-07**: 扩展回 7 层模型（新增 depth_preference + judgment_angles）

### Anti-Echo-Chamber

- [ ] **ANTI-01**: 内容配额机制（日报：核心 50% / 邻近 20% / 热点 15% / 探索 15%）
- [ ] **ANTI-02**: 配额执行算法（按 final_score 降序 → 分组取 top-K → 单向链式让渡）
- [ ] **ANTI-03**: 反向多样性约束（同主题 > 60% 连续 3 天 → 上限 50%；同来源 > 30% → 上限 20%；同事件 > 3 天 → 仅新进展推送）
- [ ] **ANTI-04**: 热点注入（importance ≥ 0.8 强制进入候选池，仍经质量判断和去重）
- [ ] **ANTI-05**: 偏好纠偏（类目最小 2% 曝光，周报 ≥ 5 类目，每 7 天 exploration_appetite +0.05 上限 0.4）

### Output Generation

- [x] **OUT-01**: 日报生成（核心关注 + 相关动态 + 今日热点 + 探索发现 + 事件跟踪，15-25 条）
- [x] **OUT-02**: 快讯输出（importance ≥ 0.85 触发，无内容不输出，宁缺毋滥）
- [ ] **OUT-03**: 周报生成（一周趋势回顾 + 事件时间线 + 跨领域总结，30-50 条）
- [ ] **OUT-04**: 输出解释字段（探索/热点位附推荐理由）
- [x] **OUT-05**: 质量感知输出（内容不足时缩短而非硬凑，空输入不生成空日报）
- [x] **OUT-06**: 运行透明化（输出尾部显示来源数、处理条数、LLM 调用次数、缓存命中）

### Feedback Learning

- [x] **FB-01**: 8 种反馈类型（more/less/trust_source/distrust_source/like/dislike/block_pattern/adjust_style）
- [x] **FB-02**: 增量偏好更新（读取未处理反馈 → 按时间顺序应用 → 原子写入）
- [x] **FB-03**: 反馈引用消歧（消息回复 → 序号引用 → 关键词搜索 → 事件引用 → 列候选）
- [x] **FB-04**: Kill Switch（feedback_processing_enabled: false 冻结偏好更新）
- [x] **FB-05**: 大幅调整升级确认（单次变化 > 0.3 需人工确认）

### Cost Control

- [x] **COST-01**: 日预算上限（daily_llm_call_limit 默认 500，daily_token_limit 默认 1M）
- [x] **COST-02**: 熔断机制（超 80% 告警，100% 停止非必要调用仅保留日报生成）
- [x] **COST-03**: LLM 结果缓存（classify-cache + summary-cache，URL SHA 为 key，7 天 TTL）
- [x] **COST-04**: 分级模型策略（简单任务用快速模型，复杂任务用强模型）

### Monitoring

- [x] **MON-01**: 每日健康指标文件（sources/items/llm/output/feedback 维度）
- [x] **MON-02**: 告警条件（全来源连续 2 天失败、预算 80%、dedup 不一致、来源集中度、空日报）
- [x] **MON-03**: 每周健康巡检（dedup-index 一致性、空事件、长期未归档、成功率、偏好极端值、缓存清理）
- [x] **MON-04**: 数据生命周期管理（30 天 news、7 天 dedup-index、90 天 feedback 明细、7 天缓存）

### History Query

- [ ] **HIST-01**: 最近动态查询（最近 24 小时）
- [ ] **HIST-02**: 主题回顾（按类目过滤近 N 天）
- [ ] **HIST-03**: 事件跟踪查询（查 active 事件后续）
- [ ] **HIST-04**: 热点扫描（高 importance 但不在偏好中的内容）
- [ ] **HIST-05**: 来源分析与健康查询
- [ ] **HIST-06**: 偏好状态查询（文字化描述）

### Platform Integration

- [x] **PLAT-01**: Cron job 配置（日报 0 8 / 快讯 */2h / 周报周日 20:00 / 巡检周一 03:00）
- [x] **PLAT-02**: Delivery 配置（announce 模式推送到聊天渠道）
- [x] **PLAT-03**: Isolated session 执行（cron 触发独立会话）
- [x] **PLAT-04**: Platform 能力验证（isolated session / exec / browser / delivery / timeout）

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Advanced Processing

- **ADV-01**: Embedding 替代 Jaccard 进行语义去重
- **ADV-02**: 情感分析能力
- **ADV-03**: 热点预测（基于数据积累）

### Advanced Feedback

- **ADVFB-01**: 反馈撤销 + 全量重建
- **ADVFB-02**: 日志化衰减协议
- **ADVFB-03**: A/B 测试框架

### Platform Scale

- **SCALE-01**: 多用户支持
- **SCALE-02**: 来源自动发现
- **SCALE-03**: SQLite 迁移（按需）

## Out of Scope

| Feature | Reason |
|---------|--------|
| 独立后端服务 | 必须作为 OpenClaw Skill 运行，复用平台能力 |
| 实时聊天功能 | 复杂度高，非核心价值 |
| 视频内容处理 | 存储/带宽成本高，非核心 |
| 移动端应用 | 聊天渠道优先，移动端延后 |
| OAuth/第三方登录 | 单用户 Skill，无需独立认证 |
| 付费墙绕过 | 合规约束，尊重内容版权 |
| 原文全文存储 | 处理链不消费此字段，存储浪费 |
| 晚报输出 | 与日报重叠度高 |
| 专题追踪输出 | 可用事件时间线 + 查询替代 |

## Traceability

Which phases cover which requirements. Updated during roadmap creation.

| Requirement | Phase | Status |
|-------------|-------|--------|
| FRMW-01 | Phase 0 | Complete |
| FRMW-02 | Phase 0 | Complete |
| FRMW-03 | Phase 0 | Complete |
| FRMW-04 | Phase 0 | Complete |
| FRMW-05 | Phase 0 | Complete |
| FRMW-06 | Phase 0 | Complete |
| SRC-01 | Phase 0 | Complete |
| SRC-02 | Phase 1 | Complete |
| SRC-03 | Phase 1 | Complete |
| SRC-04 | Phase 1 | Complete |
| SRC-05 | Phase 1 | Complete |
| SRC-06 | Phase 1 | Complete |
| SRC-07 | Phase 1 | Complete |
| SRC-08 | Phase 1 | Complete |
| SRC-09 | Phase 3 | Pending |
| SRC-10 | Phase 1 | Complete |
| PROC-01 | Phase 0 | Complete |
| PROC-02 | Phase 0 | Complete |
| PROC-03 | Phase 0 | Complete |
| PROC-04 | Phase 2 | Complete |
| PROC-05 | Phase 0 | Complete |
| PROC-06 | Phase 2 | Complete |
| PROC-07 | Phase 0 | Complete |
| PROC-08 | Phase 0 | Complete |
| EVT-01 | Phase 2 | Complete |
| EVT-02 | Phase 2 | Complete |
| EVT-03 | Phase 2 | Complete |
| EVT-04 | Phase 2 | Complete |
| EVT-05 | Phase 2 | Complete |
| PREF-01 | Phase 1 | Complete |
| PREF-02 | Phase 0 | Complete |
| PREF-03 | Phase 1 | Complete |
| PREF-04 | Phase 3 | Pending |
| PREF-05 | Phase 1 | Complete |
| PREF-06 | Phase 3 | Pending |
| PREF-07 | Phase 3 | Pending |
| ANTI-01 | Phase 2 | Pending |
| ANTI-02 | Phase 2 | Pending |
| ANTI-03 | Phase 2 | Pending |
| ANTI-04 | Phase 2 | Pending |
| ANTI-05 | Phase 2 | Pending |
| OUT-01 | Phase 0 | Complete |
| OUT-02 | Phase 1 | Complete |
| OUT-03 | Phase 3 | Pending |
| OUT-04 | Phase 2 | Pending |
| OUT-05 | Phase 0 | Complete |
| OUT-06 | Phase 1 | Complete |
| FB-01 | Phase 1 | Complete |
| FB-02 | Phase 1 | Complete |
| FB-03 | Phase 1 | Complete |
| FB-04 | Phase 1 | Complete |
| FB-05 | Phase 1 | Complete |
| COST-01 | Phase 0 | Complete |
| COST-02 | Phase 1 | Complete |
| COST-03 | Phase 1 | Complete |
| COST-04 | Phase 1 | Complete |
| MON-01 | Phase 0 | Complete |
| MON-02 | Phase 2 | Complete |
| MON-03 | Phase 2 | Complete |
| MON-04 | Phase 2 | Complete |
| HIST-01 | Phase 3 | Pending |
| HIST-02 | Phase 3 | Pending |
| HIST-03 | Phase 3 | Pending |
| HIST-04 | Phase 3 | Pending |
| HIST-05 | Phase 3 | Pending |
| HIST-06 | Phase 3 | Pending |
| PLAT-01 | Phase 0 | Complete |
| PLAT-02 | Phase 0 | Complete |
| PLAT-03 | Phase 0 | Complete |
| PLAT-04 | Phase 0 | Complete |

**Coverage:**
- v1 requirements: 70 total
- Mapped to phases: 70
- Unmapped: 0

**By phase:**
- Phase 0: 22 requirements (FRMW x6, SRC x1, PROC x6, PREF x1, OUT x2, COST x1, MON x1, PLAT x4)
- Phase 1: 21 requirements (SRC x7, PREF x3, OUT x2, FB x5, COST x3)
- Phase 2: 16 requirements (PROC x2, EVT x5, ANTI x5, OUT x1, MON x3)
- Phase 3: 11 requirements (SRC x1, PREF x3, OUT x1, HIST x6)

---
*Requirements defined: 2026-03-31*
*Last updated: 2026-03-31 after roadmap creation -- traceability complete*
