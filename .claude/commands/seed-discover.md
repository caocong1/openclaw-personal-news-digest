# Seed Discover — 新闻源发现命令

从 B站 UP主链接、视频链接、或任意 URL 发现并生成候选新闻源，输出到 `data/source-discovery/pending-seeds.json` 供 OpenClaw 消费。

## 输入

用户通过 `$ARGUMENTS` 提供一个或多个输入（空格或换行分隔）：
- B站短链接: `https://b23.tv/xxx`
- B站UP主主页: `https://space.bilibili.com/{mid}`
- B站视频: `https://www.bilibili.com/video/BVxxx`
- 任意网页URL: `https://example.com/news-roundup`
- UP主名字: 直接搜索

## 执行流程

### Step 1: 解析输入

对每个输入项：

1. **B站短链接** (`b23.tv`): 用 `WebFetch` 跟随重定向，判断目标是视频还是空间页
2. **B站空间页** (`space.bilibili.com/{mid}` 或 `bilibili.com/space/{mid}`):
   - `WebFetch` 调用 `https://api.bilibili.com/x/web-interface/card?mid={mid}` 获取UP主名字
   - `WebSearch` 搜索 `"{UP主名}" site:bilibili.com 最新` 获取最新视频列表
   - 取前3个视频URL
3. **B站视频** (`bilibili.com/video/BVxxx`):
   - 提取BV号
   - `WebFetch` 调用 `https://api.bilibili.com/x/web-interface/view?bvid={bvid}` 获取 title, desc, tags
4. **普通URL**: `WebFetch` 获取页面内容
5. **纯文本/UP主名字**: `WebSearch` 搜索相关内容

### Step 2: 提取新闻主题

从所有获取到的内容中提取新闻主题：

- 如果视频有结构化描述（编号+话题）→ 直接提取每条话题
- 如果描述为空 → 从标题提取（标题通常格式为 "话题A；话题B | AI日报"）
- 多个视频时合并所有主题，去重
- 目标：提取 3-10 个独立新闻主题，每个生成一个搜索词

### Step 3: 搜索候选源

对每个主题（最多搜索 8 个主题）：

1. `WebSearch` 搜索该主题的英文关键词（优先英文源，覆盖面更广）
2. 从搜索结果中收集域名
3. 过滤掉：
   - 已在 `config/sources.json` 中的域名（读取文件检查）
   - 社交平台域名（bilibili, youtube, twitter, weibo, zhihu 等）
   - 电商域名（taobao, jd, tmall 等）
   - 聚合/转载站（medium.com 个人博客除外）
4. 合并去重，按出现频次排序

### Step 4: 评估候选源

对每个候选源（最多 15 个）：

1. `WebFetch` 访问首页，获取概要信息
2. 判断：
   - **recommended_type**: 优先检测 RSS/Atom feed（找 `<link rel="alternate" type="application/rss+xml">`），否则按页面类型判断为 official/community/ranking/search
   - **topics**: 映射到项目的 12 个类目 ID：`ai-models`, `dev-tools`, `tech-products`, `business`, `finance`, `macro-policy`, `international`, `security`, `open-source`, `gaming`, `science`, `breaking`
   - **credibility_estimate**: 0.0-1.0，知名媒体给高分
   - **language**: en/zh/mixed
   - **update_frequency**: hourly/daily/weekly/irregular

### Step 5: 生成 pending-seeds.json

读取现有 `data/source-discovery/pending-seeds.json`（如果存在），合并新发现的候选源（按 URL 去重），然后写入完整文件。

输出格式：

```json
{
  "_generated_at": "ISO timestamp",
  "_generated_by": "claude-code",
  "seeds": [
    {
      "seed_url": "原始输入URL",
      "seed_platform": "bilibili|generic",
      "up_name": "UP主名或页面作者",
      "up_bio": "简介",
      "analyzed_videos": [
        {
          "bvid": "BVxxx",
          "title": "视频标题",
          "description": "视频描述"
        }
      ],
      "topics_extracted": ["topic1", "topic2"]
    }
  ],
  "candidate_sources": [
    {
      "url": "https://example.com",
      "rss_url": "https://example.com/feed/ 或 null",
      "name": "Source Name",
      "name_zh": "中文名",
      "recommended_type": "rss|official|community|ranking|search|github",
      "topics": ["ai-models"],
      "credibility_estimate": 0.85,
      "language": "en",
      "update_frequency": "daily",
      "discovery_reason": "发现原因",
      "matched_topics": ["匹配的主题"]
    }
  ]
}
```

### Step 6: 报告结果

输出简洁报告：

```
Seed Discovery 完成:
- 分析了 N 个种子输入（M 个视频）
- 提取了 X 个新闻主题
- 发现了 Y 个候选新闻源（其中 Z 个有RSS）

候选源列表:
1. TechCrunch (rss) — ai-models, business — 可信度 0.9
2. ...

已写入 data/source-discovery/pending-seeds.json
→ 在 OpenClaw 中说 "加载预取的种子" 即可导入
```

## 注意事项

- 合并模式：如果 pending-seeds.json 已存在，合并而非覆盖（按 candidate URL 去重）
- 每个 WebSearch 之间不需要延迟，并行搜索
- 如果 B站 API 返回限流(-799)或403，回退到 WebSearch 找视频信息
- 不要修改 `config/sources.json`，那是 OpenClaw 的职责
