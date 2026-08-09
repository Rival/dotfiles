# L3 Domain Reference Template

Generate `references/L3-domains/{domain}.md` using this structure:

```markdown
# {DomainName} Domain

{One-line description}

## Overview

{2-3 sentences: purpose, scope, key responsibility}

## Architecture

```
{ASCII diagram showing domain components and relationships}
```

## Key Classes

| Class | Path | Purpose |
|-------|------|---------|
| {ClassName} | `{path/to/file}` | {brief description} |

## Data Models

### {ModelName}

| Field | Type | Purpose |
|-------|------|---------|
| {field} | `{type}` | {desc} |

### {EnumName} (if applicable)

| Value | Description |
|-------|-------------|
| {val} | {desc} |

## {ServiceName} API

| Method | Purpose |
|--------|---------|
| `{Method(params)}` | {description} |

## Flow

```
1. {Step} -> `{Method()}`
2. {Step} -> `{Method()}`
3. {Step} -> `{Method()}`
```

## Analytics Events (if applicable)

| Event | When | Parameters |
|-------|------|------------|
| {name} | {trigger} | {params} |

## Configuration (if applicable)

| Setting | Type | Default | Purpose |
|---------|------|---------|---------|
| {key} | `{type}` | `{val}` | {desc} |

## Paths

| What | Path |
|------|------|
| Code | `{path}` |
| Config | `{path}` |
| Tests | `{path}` |

## Related References

- [L1-architecture.md](../L1-architecture.md) — overall architecture
- [{related}.md]({related}.md) — {description}
```

## Discovery Steps

1. Find service entry points: `*Service.*`, `*Manager.*`, `*Controller.*`
2. Find configs: `*Config.*`, `*Settings.*`, `*Options.*`
3. Find models: `*Model.*`, `*Data.*`, `*Entity.*`, `*Dto.*`
4. Trace initialization flow
5. Map public API methods
6. Find analytics/events (if any)

## Rules

- No emojis in headers
- English-only headers (body can match project language)
- Tables over prose
- Method signatures only — no implementation code
- ASCII architecture diagrams
- Include Related References links
- Skip sections that don't apply

## Section Order

1. Title + one-line description
2. Overview
3. Architecture diagram
4. Key Classes
5. Data Models (if any)
6. API methods
7. Flow
8. Analytics (if any)
9. Configuration (if any)
10. Paths
11. Related References
