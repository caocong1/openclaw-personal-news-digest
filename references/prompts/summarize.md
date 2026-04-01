# Summarization Prompt Template

## Instructions

为以下新闻生成简洁的中文摘要。

## Requirements

- **Length**: 2-3 sentences (2-3 句)
- **Style**: high information density, no vague descriptions (高信息密度，避免模糊描述)
- **Content**: core facts + why it matters / impact (核心事实 + 影响/意义)
- **Non-Chinese news**: write summary in Chinese, but preserve the original title as-is (非中文新闻：摘要用中文撰写，但保留原始标题不翻译)
- **No opinions**: summarize factual content only, do not add commentary

## Input (batch, separated by ---)

For each item:

```
ID: {id}
Title: {title}
Source: {source_name}
Content: {content_snippet}
---
```

## Output

Return a JSON array with objects:

```json
{"id": "item ID", "summary": "Chinese summary text"}
```

## Quality Criteria

- Each summary must contain at least one concrete fact (number, name, date, action)
- Avoid generic phrases like "引发关注" (attracted attention) or "值得注意" (worth noting) without substance
- If content is insufficient for a meaningful summary, state the core fact only: "{who} {did what}"
- Preserve technical terms and proper nouns in their original form (e.g., "GPT-4", "Series B", "Rust")

## Output Format

Return ONLY a valid JSON array. No markdown fencing, no explanation outside the JSON.

Example:
```
[{"id":"abc123","summary":"OpenAI 发布 GPT-5 模型，在数学推理和代码生成基准测试中较前代提升约 30%。该模型已向 API 用户开放，定价与 GPT-4 持平。"}]
```
