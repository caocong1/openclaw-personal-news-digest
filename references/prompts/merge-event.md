# Event Merge Prompt

一条新新闻需要判断是否属于以下已有事件之一。

## 新新闻

标题：{news_title}
摘要：{news_summary}
类目：{news_primary_category}

## 候选事件

{event_list: id, title, summary, status}

## 判断标准

- 报道的是同一个核心事件/主体 -> 归并（merge），返回事件 ID
- 仅主题相关但不是同一事件 -> 不归并
- 无匹配候选 -> 创建新事件（new）

### 关系类型说明

| 类型 | 含义 | 示例 |
|------|------|------|
| initial | 事件首次报道 | 新事件的第一条新闻 |
| update | 事件进展更新 | 后续发展、新数据、新阶段 |
| correction | 事实修正 | 更正此前错误信息、辟谣 |
| analysis | 分析评论 | 评论员/机构对事件的分析解读 |
| reversal | 形势反转 | 政策逆转、结果与预期相反 |

## 输出 JSON

```json
{
  "action": "merge|new",
  "event_id": "事件ID（merge时必填，new时留空）",
  "relation": "initial|update|correction|analysis|reversal",
  "brief": "一句话描述这条新闻在事件中的角色",
  "new_event_title": "新事件标题（仅 new 时必填）",
  "new_event_keywords": ["关键词1", "关键词2", "关键词3"]
}
```

### 输出规则

- `action` 只能是 `merge` 或 `new`
- `merge` 时必须提供 `event_id`，从候选事件中选择
- `new` 时必须提供 `new_event_title`（简洁事件标题）和 `new_event_keywords`（3-5 个关键词，用于后续匹配）
- `relation` 描述新新闻与事件的关系，`new` 时固定为 `initial`
- `brief` 始终必填，一句话说明该新闻在事件语境中的意义
- 返回纯 JSON，不要附加解释文字
