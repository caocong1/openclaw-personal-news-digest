<!-- prompt_version: summarize-v1 -->
# Summarization Prompt Template

## Instructions

为以下新闻生成简洁的中文摘要。

## User Preferences Context

Depth: {depth_preference}
Angles: {judgment_angles or "none specified"}

## Requirements

- **Style**: high information density, no vague descriptions (高信息密度，避免模糊描述)
- **Content**: core facts + why it matters / impact (核心事实 + 影响/意义)
- **Non-Chinese news**: write summary in Chinese, but preserve the original title as-is (非中文新闻：摘要用中文撰写，但保留原始标题不翻译)
- **No opinions**: summarize factual content only, do not add commentary

## Depth-Adjusted Requirements

Adjust summary length based on `{depth_preference}` (default to "moderate" if missing or empty):

- **brief**: 1 sentence per item, core fact only (1 句，仅核心事实)
- **moderate**: 2-3 sentences per item (2-3 句 -- this is the default, preserving current behavior)
- **detailed**: 3-5 sentences per item, include background context and significance (3-5 句，含背景与意义)
- **technical**: same as detailed, plus implementation/technical specifics where relevant (同 detailed，加技术细节)

## Judgment Angles

If `{judgment_angles}` is not empty: for each item where an angle applies, briefly note that perspective in the summary. Do not force angles onto items where they are not relevant.

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
