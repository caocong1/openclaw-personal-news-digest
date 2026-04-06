#!/usr/bin/env python3
import json, sys, hashlib, re, warnings, fcntl, os, tempfile
from pathlib import Path
from datetime import datetime
import xml.etree.ElementTree as ET
from urllib.parse import quote, unquote, urlparse, parse_qs
import urllib.request

BASE_DIR = Path(sys.argv[1]) if len(sys.argv) > 1 else Path.cwd()
MODE = 'daily' if '--mode' in sys.argv else 'quick-check'
SOURCES = json.loads((BASE_DIR/'config'/'sources.json').read_text(encoding='utf-8'))
ROUNDUP_PATTERNS = json.loads((BASE_DIR/'config'/'roundup-patterns.json').read_text(encoding='utf-8')).get('patterns', [])
NOW = datetime.now()
TODAY = NOW.strftime('%Y-%m-%d')
NEWS_FILE = BASE_DIR/'data'/'news'/f'{TODAY}.jsonl'
METRICS_FILE = BASE_DIR/'data'/'metrics'/f'daily-{TODAY}.json'
ALERT_FILE = BASE_DIR/'output'/'latest-alert.md'
DIGEST_FILE = BASE_DIR/'output'/'latest-digest.md'
STATE_FILE = BASE_DIR/'data'/'alerts'/f'alert-state-{TODAY}.json'
for p in [BASE_DIR/'data'/'news', BASE_DIR/'data'/'metrics', BASE_DIR/'data'/'alerts', BASE_DIR/'output']:
    p.mkdir(parents=True, exist_ok=True)
warnings.filterwarnings('ignore', category=DeprecationWarning)

LOCK_FILE = BASE_DIR / 'data' / '.pipeline.lock'
LOCK_FD = open(LOCK_FILE, 'w')
try:
    fcntl.flock(LOCK_FD, fcntl.LOCK_EX | fcntl.LOCK_NB)
except OSError:
    print('Another pipeline instance is running — exiting.', file=sys.stderr)
    sys.exit(0)

MAX_ALERTS_PER_DAY = None
MAX_PER_SOURCE_LINES = 12
MAX_ALERTS_PER_RUN = 999
ALERT_THRESHOLD = 0.85
AI_MIN_ALERT_SCORE = 0.84


def atomic_write_text(path: Path, text: str) -> None:
    """Write text atomically via tmp-file + fsync + os.replace."""
    fd, tmp = tempfile.mkstemp(dir=path.parent, suffix='.tmp')
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as f:
            f.write(text)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, str(path))
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def is_chinese(text: str) -> bool:
    return bool(re.search(r'[\u4e00-\u9fff]', text or ''))


def looks_like_package_release(title: str, url: str = '') -> bool:
    t = (title or '').strip()
    u = (url or '').lower()
    if re.search(r'\b[a-z0-9_.-]+==\d', t, re.I):
        return True
    if 'github.com/langchain-ai/langchain/releases/tag/' in u and re.search(r'==\d', u):
        return True
    return False


def is_roundup_title(title: str) -> bool:
    t = title or ''
    for p in ROUNDUP_PATTERNS:
        pat = p.get('pattern')
        if pat and re.search(pat, t, re.I):
            return True
    return False


def keep_openai_blog_alert(title: str, url: str = '') -> bool:
    low = ((title or '') + ' ' + (url or '')).lower()
    keep_patterns = [
        'acquires', 'to acquire', 'flexible pricing', 'product discovery in chatgpt',
        'gpt-5.4', 'mini and nano', 'astral', 'tbpn'
    ]
    return any(k in low for k in keep_patterns)


def zh_title(title: str) -> str:
    if not title:
        return title
    if is_chinese(title):
        return title
    mapping = {
        'Anthropic cuts off the ability to use Claude subscriptions with OpenClaw and third-party AI agents': 'Anthropic 切断 Claude 订阅与 OpenClaw 及第三方 AI 代理的连接能力',
        'OpenAI acquires TBPN': 'OpenAI 收购 TBPN',
        'Introducing GPT-5.4 mini and nano': '推出 GPT-5.4 mini 和 nano',
        'Codex now offers more flexible pricing for teams': 'Codex 现为团队提供更灵活的定价',
        'Powering product discovery in ChatGPT': '增强 ChatGPT 中的商品发现能力',
        'OpenAI to acquire Astral': 'OpenAI 将收购 Astral',
        'AI Regulation News Today - What Is Happening With US AI Laws in 2026': '今日 AI 监管新闻：2026 年美国 AI 法规正在发生什么',
    }
    if title in mapping:
        return mapping[title]
    if looks_like_package_release(title):
        m = re.match(r'^([a-z0-9_.-]+)==([\w.-]+)$', title, re.I)
        if m:
            return f"{m.group(1)} 发布新版本 {m.group(2)}"
    clean = re.sub(r'\s+', ' ', title).strip(' .-')
    patterns = [
        (r'^The AI industry is all in for the (.+?) with (.+)$', r'AI 行业正全面投入 \1，并与 \2 紧密互动'),
        (r'^AI Regulation (.+?): Compliance Realities for Developers and Companies$', r'AI 监管 \1：开发者与企业面临的合规现实'),
        (r'^(.+?): Key Regulations and Practical Guidance$', r'\1：关键监管变化与实务指引'),
        (r'^What the Regulations of (.+?) Could Mean for the AI of (.+)$', r'\1 年监管变化可能如何影响 \2 年的 AI 发展'),
        (r'^White House Releases (.+)$', r'白宫发布 \1'),
        (r'^White House AI Regulation Plan (.+)$', r'白宫 AI 监管计划 \1'),
        (r'^Microsoft launches (.+)$', r'Microsoft 推出 \1'),
        (r'^Microsoft releases (.+)$', r'Microsoft 发布 \1'),
        (r'^Introducing (.+)$', r'推出 \1'),
        (r'^OpenAI acquires (.+)$', r'OpenAI 收购 \1'),
        (r'^OpenAI to acquire (.+)$', r'OpenAI 将收购 \1'),
        (r'^(.+?) acquires (.+)$', r'\1 收购 \2'),
        (r'^Anthropic cuts off (.+)$', r'Anthropic 停止支持 \1'),
        (r'^(.+?) releases? (.+)$', r'\1 发布 \2'),
        (r'^(.+?) launches? (.+)$', r'\1 推出 \2'),
        (r'^(.+?) introduces? (.+)$', r'\1 推出 \2'),
        (r'^(.+?) announces? (.+)$', r'\1 宣布 \2'),
        (r'^(.+?) updates? (.+)$', r'\1 更新 \2'),
    ]
    for pat, rep in patterns:
        if re.match(pat, clean, re.I):
            return re.sub(pat, rep, clean, flags=re.I).strip()
    return clean


def norm_url(u: str) -> str:
    if u.startswith('//'):
        u = 'https:' + u
    if 'duckduckgo.com/l/?' in u:
        qs = parse_qs(urlparse(u).query)
        if 'uddg' in qs and qs['uddg']:
            u = unquote(qs['uddg'][0])
    return u.strip()


def hash_id(u: str) -> str:
    return hashlib.sha256(u.encode()).hexdigest()[:16]


def http_get(url, timeout=20):
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 OpenClaw-Debug/1.0'})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode('utf-8', errors='ignore'), r.geturl(), r.headers.get_content_type()


def parse_rss(text):
    items = []
    root = ET.fromstring(text)
    for el in root.findall('.//item')[:15] + root.findall('.//{http://www.w3.org/2005/Atom}entry')[:15]:
        title = ''
        link = ''
        t = el.find('title')
        if t is None:
            t = el.find('{http://www.w3.org/2005/Atom}title')
        if t is not None and t.text:
            title = t.text.strip()
        l = el.find('link')
        if l is not None:
            link = (l.text or '').strip() or l.attrib.get('href', '').strip()
        else:
            l = el.find('{http://www.w3.org/2005/Atom}link')
            if l is not None:
                link = l.attrib.get('href', '').strip() or (l.text or '').strip()
        if title or link:
            items.append({'title': title, 'url': link})
    return items


def parse_hn(text):
    out = []
    for m in re.finditer(r'<span class="titleline"><a href="([^"]+)"[^>]*>(.*?)</a>', text, re.I | re.S):
        out.append({'url': m.group(1), 'title': re.sub(r'<.*?>', '', m.group(2)).strip()})
    return out[:15]


def parse_github_trending(text):
    out = []
    for m in re.finditer(r'<h2[^>]*class="h3[^>]*>\s*<a[^>]*href="([^"]+)"[^>]*>(.*?)</a>', text, re.I | re.S):
        href = 'https://github.com' + m.group(1).strip()
        title = re.sub(r'<.*?>', '', m.group(2)).replace('\n', ' ').strip()
        out.append({'url': href, 'title': title})
    return out[:20]


def parse_github_releases_html(text, repo_url='https://github.com/langchain-ai/langchain/releases'):
    out = []
    for pat in [r'href="(/langchain-ai/langchain/releases/tag/[^"]+)"[^>]*>(.*?)</a>', r'data-view-component="true"[^>]*href="(/langchain-ai/langchain/releases/tag/[^"]+)"[^>]*>(.*?)</a>']:
        for m in re.finditer(pat, text, re.I | re.S):
            href = 'https://github.com' + m.group(1).strip()
            title = re.sub(r'<.*?>', '', m.group(2)).replace('\n', ' ').strip()
            if title and all(x['url'] != href for x in out):
                out.append({'url': href, 'title': title})
    if not out:
        out.append({'url': repo_url, 'title': 'LangChain Releases'})
    return out[:15]


def parse_ddg(text):
    out = []
    for m in re.finditer(r'<a[^>]+class="result__a"[^>]+href="([^"]+)"[^>]*>(.*?)</a>', text, re.I | re.S):
        href = m.group(1)
        title = re.sub(r'<.*?>', '', m.group(2)).strip()
        out.append({'url': href, 'title': title})
    return out[:10]


def source_name(s):
    return s.get('name', s.get('id', '?'))


def score_item(title: str, url: str, source_id: str = '') -> float:
    low = ((title or '') + ' ' + (url or '')).lower()
    score = 0.55
    if any(k in low for k in ['anthropic', 'openai', 'grok', 'security', 'policy', 'regulation', 'claude', 'gpt', 'gemini', 'hack', 'breach', 'ransomware', 'phishing', 'vulnerability']):
        score = 0.87
    if any(k in low for k in ['compliance', 'practical guidance', 'outlook', 'what the regulations', 'realities for developers', 'laws update', 'guide', 'explainer', 'framework']):
        score = min(score, 0.72)
    if source_id == 'src-search-ai-regulation' and any(k in low for k in ['compliance', 'guidance', 'outlook', 'review', 'guide', 'practical', 'framework', 'laws update']):
        score = min(score, 0.68)
    if source_id == 'src-official-openai-blog' and not keep_openai_blog_alert(title, url):
        score = min(score, 0.62)
    if looks_like_package_release(title, url):
        score = min(score, 0.68)
    if is_roundup_title(title):
        score = min(score, 0.60)
    return score


def normalize_event_key(title: str, url: str = '') -> str:
    """Cluster same-event articles via specific entity anchors only.
    Strategy: use named entities + dollar amounts + specific phrases.
    Generic action words are EXCLUDED to avoid cross-event false matches.
    """
    text = title.lower()
    anchors = []
    # 1. Dollar amounts — very strong signal
    for m in re.findall(r'\$[\d.]+[BbMmKk]?', text):
        anchors.append(m.lower())
    # 2. Key company/product codenames and names
    for t in ['openai','anthropic','microsoft','google','meta','xai','apple','nvidia','ibm',
               'openclaw','claude','gpt','codex','gemma','tbpn','astral',
               'coefficient-bio','claude-code','gpt-5.4','gemma-4','chatgpt']:
        if t in text:
            anchors.append(t)
    # 3. Specific product codenames embedded in title (e.g. "gemma 4", "tbpn", "astral")
    for m in re.findall(r'\b([a-z]+[- ][0-9]+[.0-9]*)\b', text):
        anchors.append(m.lower().replace(' ', '-'))
    # 4. Specific URL path entities (but skip overly generic paths)
    for seg in re.findall(r'/([a-z]+(?:[-][a-z]+)+)(?:/|$)', (url or '')):
        seg = seg.lower()
        # Only keep if it contains a known entity or is a specific short phrase
        if len(seg) > 5 and not seg.startswith(('according','reportedly','article','index','www')):
            anchors.append(seg)
    # 5. Multi-word specific phrases (entity+action combos)
    phrases = [
        'openai-acquires','anthropic-acquires','anthropic-buys','anthropic-launches',
        'microsoft-launches','google-releases','google-battles',
        'tbpn','astral','coefficient-bio',
        'claude-cutoff','openclaw-cutoff',
        'safety-bug-bounty','bug-bounty',
        'european-commission-hack','cert-eu',
        'claude-code-leak','claude-code-infostealer',
    ]
    for p in phrases:
        if p in text:
            anchors.append(p)
    anchors.sort()
    return '|'.join(anchors)


def ai_score_item(title: str, url: str, source_name: str = '', source_id: str = ''):
    title_low = (title or '').lower()
    low = (title_low + ' ' + (url or '').lower() + ' ' + (source_name or '').lower())

    def has_any(text, words):
        return any(w in text for w in words)

    if is_roundup_title(title) or has_any(title_low, [' roundup', ' round-up', 'weekly', 'top stories', 'what you need to know', 'latest updates', 'what it means']) or (',' in (title or '') and has_any(title_low, [' and '])):
        return 0.58, '综述/汇总型内容，降低快讯优先级'

    if has_any(title_low, ['acquire', 'acquires', 'acquisition', 'buys', 'to acquire', 'merger', 'deal']) and has_any(title_low, ['openai', 'anthropic', 'google', 'meta', 'xai', 'microsoft']):
        return 0.94, '大厂并购/交易事件，优先级很高'

    if has_any(title_low, ['gpt-5.4', 'gemma 4', 'new ai models', 'new high-speed voice and image models', 'mini and nano']) or (has_any(title_low, ['introducing', 'launches', 'launch', 'releases']) and has_any(title_low, ['model', 'models', 'gpt', 'gemma', 'claude', 'codex', 'voice', 'image'])):
        return 0.91, '新模型/核心产品发布，属于强快讯'

    if has_any(title_low, ['cuts off', 'no longer free', 'pay extra', 'pricing', 'subscription', 'subscribers', 'usage-based pricing']) and has_any(title_low, ['openclaw', 'claude', 'anthropic', 'codex', 'chatgpt business']):
        return 0.86, '直接影响用户和开发者使用方式'

    if has_any(title_low, ['hack exposes data', 'data breach', 'breached', 'ransomware', 'pre-auth rce', 'phishing attacks surge', 'infostealer', 'supply-chain', 'supply chain', 'malware']) and has_any(title_low, ['commission', 'eu', 'github', 'linkedin', 'windows', 'zendesk', 'sharefile', 'axios', 'claude code', 'drift']):
        return 0.87, '明确安全事件/高危漏洞，事件性较强'

    if has_any(title_low, ['regulation', 'framework', 'laws', 'compliance', 'around the world', 'explained', 'guide']):
        return 0.70, '更偏综述/解读，不应与硬新闻同权'

    if has_any(title_low, ['special projects', 'private markets', 'ipo hopes', 'venture funding', 'raises $', 'funding', 'digital wallet', 'face id-style', 'betting $', 'valuation', 'go public', 'spac']):
        return 0.78, '行业/融资/市场动态，重要但不算最强快讯'

    if has_any(title_low, ['functional emotions', 'trail us peers', 'hacking drones', 'shared data language', 'knowledge base', 'research']) or title_low.endswith('?'):
        return 0.74, '研究、观点或解释型内容'

    if has_any(title_low, ['bug bounty', 'safety bug bounty']):
        return 0.80, '安全计划/项目发布，值得关注但不是头条级'

    if has_any(title_low, ['openai', 'anthropic', 'microsoft', 'meta', 'claude', 'gpt', 'gemma', 'google']) and not has_any(title_low, ['outlook', 'artemis', 'odd media buy', 'bank customer', 'foundation', 'creating with sora safely', 'model spec', 'safer ai experiences for teens', 'disaster response', 'knowledge work']):
        return 0.82, '大厂相关动态，值得关注'

    return 0.68, '一般行业动态'


per = []
news = []
seen = set()
alerts = []
for s in SOURCES:
    if not s.get('enabled', True):
        continue
    entry = {'source_id': s['id'], 'source_name': source_name(s), 'status': 'unknown', 'fetched': 0, 'new_items': 0, 'processed': 0, 'filtered': 0, 'note': ''}
    try:
        items = []
        if s['type'] == 'search':
            keywords = s.get('fetch_config', {}).get('keywords', [])[:3]
            for kw in keywords:
                text, final_url, ctype = http_get('https://duckduckgo.com/html/?q=' + quote(kw))
                items.extend(parse_ddg(text))
            ded = []
            localseen = set()
            for it in items:
                u = norm_url(it.get('url', ''))
                if u and u not in localseen:
                    it['url'] = u
                    localseen.add(u)
                    ded.append(it)
            items = ded[:10]
            entry['note'] = 'search probe via DDG HTML'
        else:
            url = s.get('url') or s.get('fetch_config', {}).get('rss_url') or ''
            text, final_url, ctype = http_get(url)
            if s['type'] in ('rss', 'official') and ('xml' in ctype or text.lstrip().startswith('<?xml') or '<rss' in text[:500] or '<feed' in text[:500]):
                items = parse_rss(text)
            elif s['type'] == 'github':
                try:
                    arr = json.loads(text)
                    items = [{'title': x.get('name') or x.get('tag_name') or 'release', 'url': x.get('html_url') or x.get('url')} for x in arr[:15]]
                except Exception:
                    items = []
            elif s['type'] == 'community' and 'ycombinator.com' in (final_url or url):
                items = parse_hn(text)
            elif s['type'] == 'ranking' and 'github.com/trending' in (final_url or url):
                items = parse_github_trending(text)
            if not items:
                m = re.findall(r'<title[^>]*>(.*?)</title>', text[:5000], re.I | re.S)
                title = re.sub(r'\s+', ' ', m[0]).strip() if m else final_url
                items = [{'title': title, 'url': final_url}]
        entry['fetched'] = len(items)
        entry['status'] = 'success' if items else 'empty'
        for it in items[:15]:
            u = norm_url(it.get('url') or '')
            if not u or u in seen:
                continue
            seen.add(u)
            t = (it.get('title', '') or '')
            score = score_item(t, u, s['id'])
            ai_score, ai_reason = ai_score_item(t, u, source_name(s), s['id'])
            rec = {
                'id': hash_id(u), 'url': u, 'title': t, 'title_zh': zh_title(t), 'source_id': s['id'],
                'source_name': source_name(s), 'importance_score': score, 'ai_importance_score': ai_score,
                'ai_reason': ai_reason, 'processing_status': 'complete',
                'fetched_at': NOW.isoformat(timespec='seconds'), 'digest_eligible': True
            }
            news.append(rec)
            entry['new_items'] += 1
            entry['processed'] += 1
            if ai_score >= AI_MIN_ALERT_SCORE and not looks_like_package_release(t, u) and not is_roundup_title(t):
                alerts.append(rec)
    except Exception as e:
        msg = str(e)[:180]
        if s['type'] == 'github' and ('rate limit' in msg.lower() or '403' in msg.lower()):
            try:
                text, final_url, ctype = http_get('https://github.com/langchain-ai/langchain/releases')
                items = parse_github_releases_html(text)
                entry['fetched'] = len(items)
                entry['status'] = 'success' if items else 'failed'
                entry['note'] = 'fallback to GitHub releases HTML after API limit'
                for it in items[:15]:
                    u = norm_url(it.get('url') or '')
                    if not u or u in seen:
                        continue
                    seen.add(u)
                    t = (it.get('title', '') or '')
                    score = score_item(t, u, s['id'])
                    ai_score, ai_reason = ai_score_item(t, u, source_name(s), s['id'])
                    rec = {
                        'id': hash_id(u), 'url': u, 'title': t, 'title_zh': zh_title(t), 'source_id': s['id'],
                        'source_name': source_name(s), 'importance_score': score, 'ai_importance_score': ai_score,
                        'ai_reason': ai_reason, 'processing_status': 'complete',
                        'fetched_at': NOW.isoformat(timespec='seconds'), 'digest_eligible': True
                    }
                    news.append(rec)
                    entry['new_items'] += 1
                    entry['processed'] += 1
                    if ai_score >= AI_MIN_ALERT_SCORE and not looks_like_package_release(t, u) and not is_roundup_title(t):
                        alerts.append(rec)
            except Exception as e2:
                entry['status'] = 'failed'
                entry['note'] = 'github api limited; html fallback failed: ' + str(e2)[:120]
        else:
            entry['status'] = 'failed'
            entry['note'] = msg
    per.append(entry)

atomic_write_text(NEWS_FILE, '\n'.join(json.dumps(r, ensure_ascii=False) for r in news) + '\n' if news else '')

report = {
    '_schema_v': 1,
    'date': TODAY,
    'generated_at': NOW.isoformat(timespec='seconds'),
    'mode': MODE,
    'sources': {
        'total': len(per),
        'success': sum(1 for x in per if x['status'] == 'success'),
        'failed': sum(1 for x in per if x['status'] == 'failed'),
        'empty': sum(1 for x in per if x['status'] == 'empty')
    },
    'items': {
        'fetched': sum(x['fetched'] for x in per),
        'new': sum(x['new_items'] for x in per),
        'processed': sum(x['processed'] for x in per),
        'filtered': sum(x['filtered'] for x in per)
    },
    'alerts_sent_today': 0,
    'per_source': {x['source_id']: x for x in per},
    'scan_report': {
        'run_time': NOW.isoformat(timespec='seconds'),
        'mode': MODE,
        'sources_enabled': len(per),
        'sources_success': sum(1 for x in per if x['status'] == 'success'),
        'sources_failed': sum(1 for x in per if x['status'] == 'failed'),
        'sources_empty': sum(1 for x in per if x['status'] == 'empty'),
        'items_fetched': sum(x['fetched'] for x in per),
        'items_new': sum(x['new_items'] for x in per),
        'items_processed': sum(x['processed'] for x in per),
        'items_filtered': sum(x['filtered'] for x in per),
        'alert_candidates': sum(1 for x in news if float(x.get('ai_importance_score', x['importance_score'])) >= AI_MIN_ALERT_SCORE and not looks_like_package_release(x['title'], x['url']) and not is_roundup_title(x['title'])),
        'alerts_sent_this_run': 0,
        'run_conclusion': '',
        'per_source_brief': per
    }
}
# Reset state if date mismatch (prevents stale alerted_urls)
state = {'date': TODAY, 'alerts_sent': 0, 'alerted_urls': []}
if STATE_FILE.exists():
    try:
        prev = json.loads(STATE_FILE.read_text(encoding='utf-8'))
        if prev.get('date') == TODAY:
            state = prev
    except Exception:
        pass
state.setdefault('alerted_urls', [])
# Deduplicate already-normalized URLs
state['alerted_urls'] = list(dict.fromkeys([norm_url(u) for u in state.get('alerted_urls', []) if u]))
# Recalculate count from URL list (not stale number)
state['alerts_sent'] = len(state['alerted_urls'])

alerts = sorted(alerts, key=lambda x: (-float(x.get('ai_importance_score', x.get('importance_score', 0))), -float(x.get('importance_score', 0)), x.get('source_name', ''), x.get('title', '')))

# Sort alerts by AI score descending
alerts = sorted(alerts, key=lambda x: (
    -float(x.get('ai_importance_score', x.get('importance_score', 0))),
    x.get('source_name', ''), x.get('title', '')))

# Event-level dedup via pairwise union-find
import re as _re

_EXCL = frozenset({'apache-2.0','apache 2.0','apache2','open-source','open source','open-weights','openweights','open-weight'})
_GEN = frozenset({'openai','anthropic','microsoft','google','meta','xai','apple','nvidia','ibm','openclaw','claude','gpt','codex','gemma','chatgpt'})

def _anchors(title, url=''):
    t = title.lower(); s = set()
    for m in _re.findall(r'\$[\d.]+[BbMmKk]?', t): s.add(m.lower())
    for m in _re.findall(r'\b([A-Z]{3,6})\b', title): s.add(m.lower())
    for m in _re.findall(r'\b([a-z]+[- ][0-9]+(?:\.[0-9]+)*)\b', t):
        v = m.replace(' ', '-').lower()
        if v not in _EXCL: s.add(v)
    for p in ['openai acquires','anthropic acquires','anthropic buys','anthropic launches','anthropic cuts','anthropic ramps','microsoft launches','google releases','google battles','european commission hack','claude code leak','anthropic cuts claude','claude subscribers pay extra','no longer free claude']:
        if p in t: s.add(p)
    for seg in _re.findall(r'/([a-z]+(?:[-][a-z]+)+)(?:/|$)', (url or '')):
        seg = seg.lower()
        if 5 <= len(seg) <= 30 and not seg.startswith(('according','article','index','feed','www','venturebeat','techcrunch','theregister','siliconangle','geekwire','engadget','bleepingcomputer','thenextweb','openai','anthropic','microsoft','google')):
            s.add(seg)
    return s

def _same_event(a, b):
    a1, a2 = _anchors(a.get('title',''), a.get('url','')), _anchors(b.get('title',''), b.get('url',''))
    shared = a1 & a2
    if any(x.startswith('$') for x in shared): return True
    ca = [x for x in shared if ' ' in x and any(c in x for c in ('openai','anthropic','microsoft','google','european','claude'))]
    if ca: return True
    codename = [x for x in shared if len(x) >= 3 and x not in _GEN and x not in _EXCL and not any(x.startswith(e) for e in ('apache','open-','openw'))]
    if codename: return True
    slug = [x for x in shared if len(x) <= 30 and not any(x.startswith(g) for g in ('according','article','index','feed','www','venturebeat','techcrunch','theregister','siliconangle','geekwire','engadget','bleepingcomputer','thenextweb'))]
    if slug: return True
    return False

n = len(alerts)
_parent = list(range(n))
def _find(x):
    while _parent[x] != x:
        _parent[x] = _parent[_parent[x]]; x = _parent[x]
    return x
def _union(x, y):
    px, py = _find(x), _find(y)
    if px != py: _parent[px] = py

for i in range(n):
    for j in range(i+1, n):
        if _same_event(alerts[i], alerts[j]): _union(i, j)

# Pick one per event, URL-dedup, sorted by score
_final = []
_seen_event = set()
_seen_url = set(state['alerted_urls'])
for a in alerts:
    gid = _find(alerts.index(a))
    cu = norm_url(a.get('url',''))
    if gid not in _seen_event and cu not in _seen_url:
        _final.append(a)
        _seen_event.add(gid)
        _seen_url.add(cu)
alerts = _final

selected_alerts = alerts[:MAX_ALERTS_PER_RUN]
out = []
alert_content = ''
digest_content = ''
if MODE == 'quick-check' and selected_alerts:
    new_urls = []
    for idx, selected_alert in enumerate(selected_alerts, 1):
        su = norm_url(selected_alert['url'])
        new_urls.append(su)
        out += [f"【快讯 {idx}】{selected_alert['title_zh'] or selected_alert['title']}"]
        if selected_alert['title'] and not is_chinese(selected_alert['title']):
            out.append(f"原文标题: {selected_alert['title']}")
        out += ['', f"来源: {selected_alert['source_name']} | AI重要性: {selected_alert.get('ai_importance_score', selected_alert['importance_score'])} | 旧分: {selected_alert['importance_score']}", f"理由: {selected_alert.get('ai_reason', '未提供')}", f"链接: {selected_alert['url']}", '']
    state['alerted_urls'] = list(dict.fromkeys(state['alerted_urls'] + new_urls))
    state['alerts_sent'] = len(state['alerted_urls'])
    state['date'] = TODAY
    report['alerts_sent_today'] = state['alerts_sent']
    report['scan_report']['alerts_sent_this_run'] = len(selected_alerts)
    report['scan_report']['run_conclusion'] = f'已发送 {len(selected_alerts)} 条快讯'
    alert_content = '\n'.join(out).strip() + '\n'
elif MODE == 'quick-check':
    report['alerts_sent_today'] = state.get('alerts_sent', 0)
    report['scan_report']['run_conclusion'] = '未发送告警：候选已去重或不满足发送条件'
    alert_content = ''
else:
    report['scan_report']['run_conclusion'] = '已生成调试版 daily 报告'
    digest = ['# 今日新闻摘要（调试版）', '']
    for r in news[:10]:
        digest += [f"- {r['title_zh'] or r['title']} ({r['source_name']})"]
        if r['title'] and not is_chinese(r['title']):
            digest += [f"  原文标题: {r['title']}"]
    digest_content = '\n'.join(digest) + '\n'

# CRITICAL ORDER: state first, then metrics, then output files
# A crash after state-write but before alert-write means the alert
# is lost (no duplicate on retry). A crash before state-write means
# clean retry.
atomic_write_text(STATE_FILE, json.dumps(state, ensure_ascii=False, indent=2) + '\n')
atomic_write_text(METRICS_FILE, json.dumps(report, ensure_ascii=False, indent=2) + '\n')

# Output files last — these are the "publish" step
if MODE == 'quick-check':
    ALERT_FILE.write_text(alert_content, encoding='utf-8')
else:
    DIGEST_FILE.write_text(digest_content, encoding='utf-8')

parts = []
if out:
    parts.append('\n'.join(out).strip())
lines = [
    '---', '## 本轮检测报告',
    f"- 检测时间: {report['scan_report']['run_time']}",
    f"- 检测模式: {MODE}",
    f"- 已启用来源: {report['scan_report']['sources_enabled']}",
    f"- 来源结果: 成功 {report['scan_report']['sources_success']} | 失败 {report['scan_report']['sources_failed']} | 空结果 {report['scan_report']['sources_empty']}",
    f"- 原始抓取: {report['scan_report']['items_fetched']}",
    f"- 去重后新增: {report['scan_report']['items_new']}",
    f"- 进入处理: {report['scan_report']['items_processed']}",
    f"- 噪声/规则过滤: {report['scan_report']['items_filtered']}",
    f"- 候选快讯: {report['scan_report']['alert_candidates']}",
    f"- 最终发送: {report['scan_report']['alerts_sent_this_run']}",
    f"- 本轮结论: {report['scan_report']['run_conclusion']}"
]
brief = per[:MAX_PER_SOURCE_LINES]
if brief:
    lines += ['', '### 分源明细（节选）']
    for x in brief:
        lines.append(f"- {x['source_name']}: {x['status']} | 抓取 {x['fetched']} | 新增 {x['new_items']} | 处理 {x['processed']} | 备注: {x['note'] or '-'}")
remaining = len(per) - len(brief)
if remaining > 0:
    lines.append(f"- 其余 {remaining} 个来源已省略，避免消息过长")
parts.append('\n'.join(lines))
print('\n\n'.join(parts))
