# Weekly Report Synthesis Prompt

You are generating a weekly news digest report. Your task is to synthesize {days_count} days of news data into trend analysis and cross-domain insights.

## Input Data

### Category Distribution
{category_stats: per-category item counts, week-over-week change}

### Top Events (by importance)
{event_list: event title, summary, timeline entries, item count, importance}

### Top Stories Per Category
{per_category_top_items: for each category, top 3-5 items by final_score with title, summary, source}

### Source Performance
{source_stats: source name, quality_score, status, items fetched this week}

### User Preferences Context
Depth: {depth_preference}
Angles: {judgment_angles or "none specified"}

## Output Requirements

Generate TWO sections:

### 1. One Week Overview (2-3 paragraphs)
- Identify the dominant themes and shifts of the week
- Note emerging trends or surprising developments
- Connect developments across categories when meaningful
- If judgment_angles specified, emphasize those perspectives
- Match depth to depth_preference setting

### 2. Cross-Domain Connections (3-5 bullet points)
- Identify non-obvious connections between stories in different categories
- Each connection must reference specific stories/events
- Focus on actionable insights, not vague generalizations

Output as markdown. Do not include section headers -- the caller will wrap your output in the report template.
