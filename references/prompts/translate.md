<!-- prompt_version: translate-v1 -->
# Translation Prompt Template

## Instructions

为以下非中文新闻标题生成中文翻译。

## Input News (batch, separated by ---)

For each item:

```
ID: {id}
Title: {title}
Source: {source_name}
---
```

_(Note: Process 5-10 items per call. Each item includes `id`, `title`, and `source`, separated by `---`.)_

## Required Output

For each news item, return a JSON object in a JSON array:

```json
{
  "id": "news item ID",
  "translated_title": "Chinese translated title, or original title if already Chinese",
  "original_title": "original title exactly as provided"
}
```

## Quality Criteria

- Preserve proper nouns in their original form (e.g., "GPT-4", "Series B", "Rust").
- Preserve technical terms, code identifiers, and domain-specific terms when translation would reduce accuracy.
- Preserve brand names, product names, company names, and project names in their original form.
- Return already-Chinese titles unchanged in `translated_title`.
- Handle mixed-language titles gracefully: translate non-Chinese natural-language parts into Chinese while preserving existing Chinese text and Latin technical terms.
- Do not over-translate version numbers, model names, API names, package names, command names, file names, or code terms.
- Keep translations concise and faithful to the original title. Do not add facts, commentary, source labels, or explanatory text.

## Edge Cases

- Titles with code/version numbers: preserve tokens such as `v1.2.3`, `Python 3.13`, `GPT-4.1`, `ES2025`, `iOS 18`, `Node.js`, and `CVE-2025-1234` exactly.
- Mixed CJK+Latin titles: keep existing CJK text, translate only the non-Chinese natural-language parts, and preserve Latin proper nouns/technical terms.

## Output Format

Return ONLY a valid JSON array. No markdown fencing, no explanation outside the JSON.

Example:
```
[{"id":"abc123","translated_title":"OpenAI 发布 GPT-4.1 模型","original_title":"OpenAI launches GPT-4.1 model"}]
```
