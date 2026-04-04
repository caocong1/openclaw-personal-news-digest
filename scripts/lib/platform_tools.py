# -*- coding: utf-8 -*-
"""Platform-specific URL resolution and metadata extraction utilities."""

from __future__ import annotations

import json
import re
import urllib.parse
import urllib.request
from typing import Optional


# Domains to exclude from news URL lists (ads, e-commerce, social profiles, etc.)
_NON_NEWS_DOMAINS = frozenset(
    [
        "taobao.com",
        "tmall.com",
        "detail.tmall.com",
        "jd.com",
        "item.jd.com",
        "douyin.com",
        "kuaishou.com",
        "pinduoduo.com",
        "suning.com",
        "vip.com",
        "dangdang.com",
        "amazon.cn",
        "bilibili.com",
        "b23.tv",
        "youtube.com",
        "youtu.be",
        "twitter.com",
        "x.com",
        "t.co",
        "weibo.com",
        "weibo.cn",
        "instagram.com",
        "facebook.com",
        "tiktok.com",
        "zhihu.com",
        "tieba.baidu.com",
        "v.qq.com",
        "iqiyi.com",
        "youku.com",
        "meituan.com",
        "ele.me",
        "dianping.com",
    ]
)


def resolve_short_url(url: str) -> str:
    """Resolve short URLs (b23.tv, t.co, etc.) to full URLs via HTTP redirect.

    Returns the final URL after following redirects.
    Falls back to original URL on failure.
    """
    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "Mozilla/5.0"},
            method="HEAD",
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            return resp.url
    except Exception:
        pass
    # Fallback: GET request (some servers don't support HEAD)
    try:
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "Mozilla/5.0"},
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            return resp.url
    except Exception:
        return url


def extract_bilibili_bvid(url: str) -> Optional[str]:
    """Extract BV number from bilibili URL.

    Handles: b23.tv short links (after resolve), bilibili.com/video/BVxxx, BVxxx direct.
    Returns BV ID string or None.
    """
    # Direct BV string (e.g. "BV1xx411c7mD")
    direct_match = re.fullmatch(r"BV[A-Za-z0-9]+", url.strip())
    if direct_match:
        return direct_match.group(0)

    # Resolve short links first
    if "b23.tv" in url:
        url = resolve_short_url(url)

    # bilibili.com/video/BVxxx path
    path_match = re.search(r"/video/(BV[A-Za-z0-9]+)", url)
    if path_match:
        return path_match.group(1)

    # Query param bvid=BVxxx
    parsed = urllib.parse.urlparse(url)
    params = urllib.parse.parse_qs(parsed.query)
    bvid = params.get("bvid", [None])[0]
    if bvid and re.match(r"BV[A-Za-z0-9]+", bvid):
        return bvid

    return None


def build_bilibili_api_url(bvid: str) -> str:
    """Build bilibili web API URL for video info.

    API: https://api.bilibili.com/x/web-interface/view?bvid={bvid}
    """
    return f"https://api.bilibili.com/x/web-interface/view?bvid={bvid}"


def parse_bilibili_video_info(api_response_text: str) -> Optional[dict]:
    """Parse bilibili API JSON response.

    Returns dict with: title, description, tags (list), tname (category),
    owner_name, bvid, duration, pub_date.
    Returns None on parse failure or error response.
    """
    try:
        data = json.loads(api_response_text)
    except json.JSONDecodeError:
        return None

    if data.get("code", -1) != 0:
        return None

    video = data.get("data", {})
    if not video:
        return None

    tags_raw = video.get("tag", "")
    if isinstance(tags_raw, str):
        tags = [t.strip() for t in tags_raw.split(",") if t.strip()]
    elif isinstance(tags_raw, list):
        tags = [t.get("tag_name", "") if isinstance(t, dict) else str(t) for t in tags_raw]
    else:
        tags = []

    owner = video.get("owner", {})

    return {
        "title": video.get("title", ""),
        "description": video.get("desc", ""),
        "tags": tags,
        "tname": video.get("tname", ""),
        "owner_name": owner.get("name", "") if isinstance(owner, dict) else "",
        "bvid": video.get("bvid", ""),
        "duration": video.get("duration", 0),
        "pub_date": video.get("pubdate", 0),
    }


def extract_bilibili_mid(url: str) -> Optional[str]:
    """Extract member ID (mid) from bilibili space/user URL.

    Handles: space.bilibili.com/{mid}, m.bilibili.com/space/{mid},
    b23.tv short links that redirect to space pages.
    Returns mid string or None.
    """
    # Resolve short links first
    if "b23.tv" in url:
        url = resolve_short_url(url)

    # space.bilibili.com/{mid} or m.bilibili.com/space/{mid}
    mid_match = re.search(r"(?:space\.bilibili\.com|bilibili\.com/space)/(\d+)", url)
    if mid_match:
        return mid_match.group(1)

    return None


def build_bilibili_card_api_url(mid: str) -> str:
    """Build bilibili web API URL for user card info.

    API: https://api.bilibili.com/x/web-interface/card?mid={mid}
    """
    return f"https://api.bilibili.com/x/web-interface/card?mid={mid}"


def parse_bilibili_card_info(api_response_text: str) -> Optional[dict]:
    """Parse bilibili user card API JSON response.

    Returns dict with: name, sign (bio), mid, follower, video_count.
    Returns None on parse failure or error response.
    """
    try:
        data = json.loads(api_response_text)
    except json.JSONDecodeError:
        return None

    if data.get("code", -1) != 0:
        return None

    card = data.get("data", {}).get("card", {})
    if not card:
        return None

    return {
        "name": card.get("name", ""),
        "sign": card.get("sign", ""),
        "mid": str(card.get("mid", "")),
        "follower": data.get("data", {}).get("follower", 0),
        "video_count": data.get("data", {}).get("archive_count", 0),
    }


def detect_platform(url: str) -> str:
    """Detect which platform a URL belongs to.

    Returns: 'bilibili', 'youtube', 'twitter', 'weibo', 'generic'
    Used for routing to platform-specific extraction logic.
    """
    try:
        host = urllib.parse.urlparse(url).netloc.lower()
    except Exception:
        return "generic"

    # Strip www. prefix for simpler matching
    if host.startswith("www."):
        host = host[4:]

    if host in ("bilibili.com", "m.bilibili.com", "space.bilibili.com", "b23.tv"):
        return "bilibili"
    if host in ("youtube.com", "youtu.be"):
        return "youtube"
    if host in ("twitter.com", "x.com", "t.co"):
        return "twitter"
    if host in ("weibo.com", "weibo.cn"):
        return "weibo"
    return "generic"


def extract_urls_from_text(text: str) -> list:
    """Extract all URLs from a text string.

    Useful for finding news source URLs in video descriptions.
    Returns list of URL strings.
    """
    pattern = r"https?://[^\s\u3000-\u9fff\u4e00-\u9fff「」【】、。，！？《》\[\]()（）<>\"'，。；：！？]+"
    matches = re.findall(pattern, text)
    # Strip trailing punctuation that may have been captured
    cleaned = []
    for m in matches:
        m = m.rstrip(".,;:!?\"'）>》])")
        if m:
            cleaned.append(m)
    return cleaned


def filter_non_news_urls(urls: list) -> list:
    """Filter out known non-news URLs (ads, social profiles, e-commerce, etc.).

    Uses domain blocklist: taobao.com, jd.com, tmall.com, detail.tmall.com,
    item.jd.com, douyin.com, kuaishou.com, etc.
    Returns filtered list.
    """
    result = []
    for url in urls:
        try:
            host = urllib.parse.urlparse(url).netloc.lower()
        except Exception:
            result.append(url)
            continue
        if host.startswith("www."):
            host = host[4:]
        # Check exact domain and subdomains
        blocked = any(
            host == domain or host.endswith("." + domain)
            for domain in _NON_NEWS_DOMAINS
        )
        if not blocked:
            result.append(url)
    return result


if __name__ == "__main__":
    pass
