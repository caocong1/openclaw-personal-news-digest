# Classification Prompt Template

## Instructions

你是一个新闻分类助手。请对以下新闻进行分类和重要性评估。

## Available Categories

{categories_list}

_(Note: The agent reads `config/categories.json` to fill this placeholder. Each category has an `id`, `name_zh`, `name_en`, and `description`.)_

The 12 category IDs are:
- `ai-models` -- AI Models: LLM, image generation, AI research, model releases, benchmarks
- `dev-tools` -- Developer Tools: IDEs, frameworks, libraries, DevOps, programming languages
- `tech-products` -- Tech Products: consumer electronics, apps, platforms, product launches
- `business` -- Business: startups, funding, acquisitions, corporate strategy
- `finance` -- Finance: stock markets, crypto, fintech, banking, investment
- `macro-policy` -- Macro Policy: government regulations, tech policy, antitrust, data privacy
- `international` -- International: global tech landscape, cross-border developments, geopolitics
- `security` -- Security: cybersecurity, vulnerabilities, data breaches, privacy incidents
- `open-source` -- Open Source: open source projects, community, license changes, major releases
- `gaming` -- Gaming: game releases, gaming industry, esports, game development
- `science` -- Science: scientific discoveries, research papers, space, biotech, climate
- `breaking` -- Breaking: high-impact breaking news across any category

## Input News (batch, separated by ---)

{news_batch}

_(Note: Each item includes `id`, `title`, `source`, `content_snippet`, separated by `---`.)_

## Required Output

For each news item, return a JSON object in a JSON array:

```json
{
  "id": "news item ID",
  "primary": "most relevant category ID from the list above",
  "tags": ["fine-grained tags, kebab-case, 2-5 tags"],
  "importance_score": 0.0,
  "form_type": "news|analysis|opinion|announcement|other",
  "reasoning": "one-sentence classification rationale (for debugging, not stored)"
}
```

## Classification Guidelines

- `primary`: Choose the SINGLE most relevant category ID. If an item spans multiple categories, pick the dominant one.
- `tags`: Generate 2-5 fine-grained tags in kebab-case (e.g., `large-language-model`, `series-b-funding`, `zero-day-exploit`). Tags should capture specific topics, technologies, companies, or concepts.
- `form_type`: Classify the content format:
  - `news` -- factual report of an event or development
  - `analysis` -- in-depth analysis or investigation
  - `opinion` -- editorial, opinion piece, or commentary
  - `announcement` -- official product release, company announcement
  - `other` -- does not fit above categories
- `reasoning`: Brief rationale for the classification decision. This is used for debugging and is NOT stored in the final record.

## Importance Score Reference

- **0.9-1.0**: Major events with broad impact (big company major decisions, critical security incidents, changes affecting 10M+ users)
- **0.7-0.8**: Significant industry/community events (important product launches, major project updates)
- **0.5-0.6**: Noteworthy developments (routine product updates, industry observations, valuable analysis)
- **0.3-0.4**: General information (routine news, daily updates)
- **0.0-0.2**: Low information density (repetitive coverage, clickbait, pure marketing)

## Output Format

Return ONLY a valid JSON array. No markdown fencing, no explanation outside the JSON.

Example:
```
[{"id":"abc123","primary":"ai-models","tags":["llm","gpt","benchmark"],"importance_score":0.7,"form_type":"news","reasoning":"New GPT model release with benchmark improvements"}]
```
