<!-- prompt_version: classify-v2 -->
# Classification Prompt Template

## Instructions

你是一个新闻分类助手。请对以下新闻进行分类和重要性评估。

## Available Categories

{categories_list}

_(Note: The agent reads `config/categories.json` to fill this placeholder. Each category has an `id`, `name_zh`, `name_en`, and `description`.)_
_(Each category also includes `negative_examples` -- items that should NOT be classified under that category. Use these to avoid common misclassifications.)_

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
- When `negative_examples` are provided for a category, actively check whether the item matches a negative example before assigning that category. If it does, choose the alternative category suggested in the negative example.
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
- **0.0-0.2**: Low information density. Assign this range to items that add little unique information value:
  - Repetitive coverage of already-well-reported events with no new facts
  - Clickbait titles without substantive content behind them
  - Pure marketing or promotional content (product ads, sponsored posts)
  - Routine minor version bumps with no notable changes (e.g., "v1.2.3 patch release")
  - Aggregated round-up posts that compile links without original analysis (e.g., "每日精选", "Weekly Roundup")
  - Social media reaction compilations without expert analysis
  - Press releases restating previously announced information

## Borderline Examples

Items near score boundaries -- use these as calibration anchors:

| Title Example | Score | Rationale |
|---------------|-------|-----------|
| "v2.1.3 bug fix release" | 0.1 | Routine patch, no notable changes |
| "本周 AI 领域十大热门文章" | 0.1 | Aggregation roundup, no original content |
| "某某公司获得 A 轮融资" (small unknown startup) | 0.3 | General business news, limited industry impact |
| "某某公司获得 B 轮 5000 万美元融资" (known company) | 0.5 | Noteworthy funding with market signal |
| "Google 发布新版 Gemini 模型" | 0.8 | Significant model release from major player |
| "重大安全漏洞影响百万用户" | 0.9 | Critical security incident with broad impact |

## Disambiguation Rules

When an item could belong to multiple categories, use these rules to determine the primary category:

- "AI startup raises funding" -> `business` (NOT `ai-models`), unless the funding is specifically tied to a new model release
- "New IDE with AI features" -> `dev-tools` (NOT `ai-models`), unless the AI capability itself is the primary news
- "Open source AI model released" -> `ai-models` (primary), `open-source` as tag. The model is the news, not the license.
- "Security vulnerability in AI system" -> `security` (NOT `ai-models`), unless the vulnerability is inherent to the model architecture itself
- "Government bans AI technology" -> `macro-policy` (NOT `ai-models`). Policy is the action; AI is the subject.
- "Game engine adds AI generation" -> `gaming` or `dev-tools` depending on audience (game devs -> `dev-tools`, gamers -> `gaming`). NOT `ai-models`.
- "Crypto exchange launches new product" -> `finance` (NOT `tech-products`). Financial product, not tech product.
- "Open source project changes license" -> `open-source` (NOT `business`). License is the core community issue.
- "Country restricts tech exports" -> `international` (NOT `macro-policy`), if cross-border. `macro-policy` if domestic-only.

**General principle:** Classify by the PRIMARY ACTION or EVENT, not by the subject domain. "AI" as a subject does not automatically mean `ai-models` -- the action (funding, regulation, vulnerability, tool release) determines the category.

## Roundup Classification

In addition to the fields above, set `is_roundup` on each output object:

- `is_roundup: true` -- The item is a collection or roundup that aggregates multiple pieces of news without original reporting or analysis. Examples: "Top 10 AI Papers", "Weekly Roundup", "5 Best Open Source LLMs". The item summarizes or links to other items rather than reporting a single story.
- `is_roundup: false` -- The item is a standalone report, article, or analysis with original content or findings. It covers a single story or topic.
- `is_roundup: null` -- Only if the item type cannot be determined (e.g., ambiguous titles).

When `is_roundup` is `true`, also populate `roundup_children` with the IDs of any known child items that should be created by atomizing this roundup (e.g., URLs or IDs extracted from the roundup's content). If no child items are known, set `roundup_children` to an empty array `[]`.

**Important:** The LLM does NOT create child items -- it only sets the `is_roundup` flag and optionally lists known child URLs/IDs in `roundup_children`. Child item creation is handled by the Collection Phase atomization step in SKILL.md.

## Output Format

Return ONLY a valid JSON array. No markdown fencing, no explanation outside the JSON.

Example:
```
[{"id":"abc123","primary":"ai-models","tags":["llm","gpt","benchmark"],"importance_score":0.7,"form_type":"news","reasoning":"New GPT model release with benchmark improvements"}]
```
