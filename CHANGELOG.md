# Changelog

## [16.1.0] - 2026-04-05

### Fixed
- Provenance classify prompt: added explicit tier definitions (T0-T4) with clear semantics — tier reflects "who published", not "how important the event is"
- LLM no longer misclassifies media outlets (e.g., 36Kr) as T0 when reporting on official announcements
- Added null fallback ("未分类") to tier Display Mapping in output-templates.md

### Changed
- Bumped provenance-classify prompt version to v2
