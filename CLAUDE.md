# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

GeoTrainer is a Geoguessr training application built with **Godot 4.5** using **GDScript**. It helps players track progress, analyze game statistics, access training resources, and run personalized training programs. It authenticates with the Geoguessr API using NCFA cookies.

## Development

- **Engine**: Godot 4.5 with GL Compatibility renderer
- **Language**: GDScript exclusively (no plugins or external dependencies)
- **Main scene**: `res://scenes/main_menu.tscn`
- **Run**: Open project in Godot 4.5 editor, press F5
- **Export**: Configured for Windows Desktop x86_64 in `export_presets.cfg`
- **No formal test suite** — testing is manual via the Godot editor

## Architecture

### Autoload Singletons
- `ResourceDatabase` (`autoload/ResourceDatabase.gd`) — global singleton managing country learning resources (docs, maps)

### Script Organization (`scripts/`)
The codebase (~3,800 lines) is organized by feature area:

- **Authentication & API**: `connection.gd` (NCFA auth), `connection_api.gd` (profile fetching via API v3)
- **Game Data Pipeline**: `import_games.gd` (fetch game tokens from API v4 feed) → `analyse_games.gd` (fetch details, detect countries via polygon data, compute stats) → `update_games.gd` (incremental updates)
- **Training Module**: `training.gd` (core training engine, largest file ~906 lines), `determine_priorities.gd` (priority scoring algorithm), `priority_panel.gd` (UI)
- **Analytics**: `duels.gd` / `duels_elo.gd` / `duels_points.gd` (duel stats, ELO charts, point trends), `country_precision.gd` (country performance heatmap), `solo_maps.gd` (solo game stats)
- **UI**: `main_menu.gd` (entry point, tab routing), `tabs.gd`, `popup_analyze.gd`

### Data Models (`data/models/`)
- `CountryResources.gd` and `DocResource.gd` — Godot `Resource` classes for country training materials
- Country-specific `.tres` files in `data/countries/`

### Static Data (`misc/`)
- `countries.json` — country code-to-name mappings (90+ countries)
- `countries_polygon.json` — polygon geometries for country detection (~1.3MB)
- `resources.json` — training resource database

### User Data (stored at `user://`, OS-specific)
Files like `ncfa.txt`, `profile.json`, `duels.json`, `solo.json`, `duels_detailed.json`, `solo_detailed.json`, `stats_detailed.json`, `training_history.json` — all JSON, read/written via Godot's `FileAccess` API.

## Key Patterns

- **API integration**: Geoguessr API v3 (`/api/v3/profiles`) for auth, API v4 (`/feed/private`) for game data with pagination. All HTTP via Godot `HTTPRequest` nodes.
- **Country detection**: Point-in-polygon algorithm using `countries_polygon.json` geometry data.
- **Game modes**: Move, NM (No Movement), NMPZ (No Movement/Pan/Zoom) — filtered throughout analysis and training.
- **Signal wiring**: Button presses, HTTP completions, tab changes, slider values all connected in `_ready()` methods.
- **File I/O**: All through `FileAccess` and `JSON.parse_string()`, no external libraries.

## Branch Strategy

| Branch | Purpose |
|--------|---------|
| `main` | Stable releases. Only maintainer merges here. |
| `develop` | Integration branch for validated features. |
| `feature/*` | New feature development. |
| `fix/*` | Bug fixes. |
