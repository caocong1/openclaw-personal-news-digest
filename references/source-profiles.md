# Source Profiles

**Document ID:** OPER-04
**Phase:** 16-operational-hardening
**Created:** 2026-04-03

## Overview

Source profiles provide named, reproducible baselines for the enabled-source configuration. Instead of manually editing `config/sources.json` each time you want to change the number of active sources, you activate a named profile with one command.

## Available Profiles

### `minimal` -- Single Source, Quick Feedback Loop

**Description:** Single source, quick feedback loop. Use for initial setup and rapid iteration.

**Sources:** `src-36kr` only

**When to use:**
- First-time setup and verification
- Debugging a specific source
- Rapid iteration when you need fast, focused results
- Testing the pipeline end-to-end

### `production` -- Multi-Source Baseline (Recommended)

**Description:** Multi-source baseline with balanced coverage. Recommended for daily operation.

**Sources:** All currently enabled sources in `sources.json` (`src-36kr`)

**When to use:**
- Daily cron-driven digest generation
- Production deployment
- Any operation where balanced multi-source coverage matters
- **This is the documented baseline for daily operation.**

### `full` -- All Configured Sources

**Description:** All configured sources including experimental and low-weight sources.

**Sources:** `*` (all sources in `sources.json`, regardless of weight or experimental status)

**When to use:**
- Periodic comprehensive scanning
- Evaluating new sources before deciding which to keep
- Discovery and research phases

## Activation

Activate a profile by running:

```bash
bash scripts/activate-profile.sh <profile_name> [base_dir]
```

Examples:

```bash
# Activate production profile (daily baseline)
bash scripts/activate-profile.sh production

# Switch to minimal for debugging
bash scripts/activate-profile.sh minimal

# Full scan with all sources
bash scripts/activate-profile.sh full

# With explicit base directory
bash scripts/activate-profile.sh production /path/to/news-digest
```

## Effect

Activating a profile updates `config/sources.json`:
- For `minimal` and `production`: enables exactly the source IDs listed in the profile, disables all others
- For `full`: enables all sources in `sources.json`

The change is atomic -- sources.json is written via a `.tmp` rename.

## Profiles File

`config/source-profiles.json` is the source of truth for profile definitions. It follows schema v1:

```json
{
  "_schema_v": 1,
  "_description": "...",
  "profiles": {
    "<name>": {
      "description": "...",
      "sources": ["src-id-1", "src-id-2"] | "*"
    }
  }
}
```

## Adding New Sources to Profiles

When you add a new source to `config/sources.json`:

1. Decide which profiles should include it
2. Update `config/source-profiles.json` to add the source ID to the appropriate profile arrays
3. Commit the change

The `production` profile is the recommended baseline -- it should contain all sources you want active during normal daily operation.
