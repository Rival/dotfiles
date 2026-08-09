# L1 Architecture Template

Generate `references/L1-architecture.md` using this structure:

```markdown
# {ProjectName} Architecture

## Tech Stack

| Component | Technology | Version |
|-----------|-----------|---------|
| Language  | {lang}    | {ver}   |
| Framework | {fw}      | {ver}   |
| Runtime   | {runtime} | {ver}   |
| Database  | {db}      | {ver}   |
| Build     | {tool}    | {ver}   |

## Platforms (if applicable)

| Platform | Target | Notes |
|----------|--------|-------|
| {name}   | {ver}  | {info} |

## Architecture Layers

```
{ASCII diagram showing layers from UI down to infrastructure}

Example:
┌──────────────────────────────┐
│         UI / API Layer       │
├──────────────────────────────┤
│      Application Layer       │
│   (Controllers, Services)    │
├──────────────────────────────┤
│        Domain Layer          │
│   (Models, Business Logic)   │
├──────────────────────────────┤
│     Infrastructure Layer     │
│  (DB, External APIs, Cache)  │
└──────────────────────────────┘
```

## Data Flow

```
{ASCII diagram showing how data moves through the system}

Example:
Client ──▶ API ──▶ Service ──▶ Repository ──▶ DB
                      │
                      ▼
                   Cache
```

## Modules

| Module | Path | Purpose |
|--------|------|---------|
| {name} | `{path}` | {description} |

## External Services

| Service | Purpose | Config |
|---------|---------|--------|
| {name}  | {desc}  | {where configured} |

## Key Patterns

| Pattern | Usage |
|---------|-------|
| {name}  | {where/how used} |

## Dependencies

### Core

| Package | Version | Purpose |
|---------|---------|---------|
| {name}  | {ver}   | {desc}  |

### Dev

| Package | Version | Purpose |
|---------|---------|---------|
| {name}  | {ver}   | {desc}  |

## Build & Deploy

| Aspect | Command / Details |
|--------|-------------------|
| Build  | `{command}`       |
| Test   | `{command}`       |
| Lint   | `{command}`       |
| Deploy | `{info}`          |

## Compilation Flags / Feature Flags (if applicable)

```
{list of conditional compilation or feature flags}
```

## Assembly / Package Structure (if applicable)

```
{dependency graph between modules/packages/assemblies}
```

## Related References

| Level | Document | Description |
|-------|----------|-------------|
| L1+   | code-architecture.md | DI, services, patterns |
| L2    | L2-project-structure.md | Folder structure |
| L3    | L3-domains/ | Domain details |
```

## Discovery Commands

Use these to gather L1 data:

```bash
# Package info
cat package.json 2>/dev/null || cat Cargo.toml 2>/dev/null || cat go.mod 2>/dev/null || cat pyproject.toml 2>/dev/null

# Folder structure
find . -maxdepth 2 -type d -not -path '*/\.*' -not -path '*/node_modules/*' -not -path '*/target/*' | head -50

# Git info
git log --oneline -5
git remote -v
```
