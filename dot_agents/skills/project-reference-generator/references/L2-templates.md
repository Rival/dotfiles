# L2 Templates

## L2-project-structure.md

```markdown
# Project Structure

## Folder Tree

```
{project}/
├── {dir1}/          # {purpose}
│   ├── {subdir}/    # {purpose}
│   └── {subdir}/    # {purpose}
├── {dir2}/          # {purpose}
└── {dir3}/          # {purpose}
```

## Module / Package Boundaries

| Module | Path | Dependencies | Exports |
|--------|------|-------------|---------|
| {name} | `{path}` | {deps} | {what it exports} |

## Dependency Graph

```
{module1}
    ↑
{module2} ←── {module3}
    ↑
{module4}
```

## Key Directories

| Directory | Purpose | Key Files |
|-----------|---------|-----------|
| `{path}` | {desc}  | `{files}` |

## Config Files

| File | Purpose |
|------|---------|
| `{file}` | {desc} |

## Test Structure

| Type | Location | Framework |
|------|----------|-----------|
| Unit | `{path}` | {fw} |
| Integration | `{path}` | {fw} |
| E2E | `{path}` | {fw} |
```

## L2-code-patterns.md

```markdown
# Code Patterns

## Naming Conventions

| Element | Pattern | Example |
|---------|---------|---------|
| Files | {pattern} | `{example}` |
| Classes | {pattern} | `{example}` |
| Functions | {pattern} | `{example}` |
| Constants | {pattern} | `{example}` |
| Tests | {pattern} | `{example}` |

## Common Patterns

### {Pattern Name}

```
{Brief description}

Usage:
{code pattern / signature}
```

### Service / DI Pattern

```
{How services are registered and resolved}
```

### Error Handling

```
{How errors are handled — exceptions, Result types, error codes}
```

### Async Patterns

```
{How async operations work — async/await, callbacks, observables}
```

### Configuration Pattern

```
{How configs are loaded and accessed}
```

### Data Access Pattern

```
{How data is queried and persisted}
```

## Anti-Patterns to Avoid

| Don't | Do Instead |
|-------|------------|
| {bad pattern} | {good pattern} |
```

## code-architecture.md

```markdown
# Code Architecture

## Dependency Injection

{How DI works in this project — container, registration, resolution}

### Service Registration

| Registration | Lifetime | Example |
|-------------|----------|---------|
| {method} | {scope} | `{code}` |

### Service Resolution

```
{How to get a service instance}
```

## State Management

{How application state is managed}

## Request / Event Flow

```
{Entry point}
    ↓
{Middleware / Pipeline}
    ↓
{Handler / Controller}
    ↓
{Service}
    ↓
{Repository / External}
```

## Key Interfaces

| Interface | Purpose | Implementations |
|-----------|---------|----------------|
| `{name}` | {desc} | `{impl1}`, `{impl2}` |

## Lifecycle

```
1. {Bootstrap step}
2. {Registration step}
3. {Initialization step}
4. {Running step}
5. {Shutdown step}
```
```

## cheatsheet.md

```markdown
# Cheatsheet

## Common Operations

| Task | Code |
|------|------|
| Get service / dependency | `{pattern}` |
| Database query | `{pattern}` |
| API call | `{pattern}` |
| Log message | `{pattern}` |
| Create test | `{pattern}` |
| Run tests | `{command}` |
| Config value | `{pattern}` |
| Error handling | `{pattern}` |
| Async operation | `{pattern}` |

## File Templates

### New Service / Module

```{lang}
{minimal template for a new service}
```

### New Test

```{lang}
{minimal template for a new test}
```
```

## glossary.md

```markdown
# Glossary

| Term | Definition |
|------|-----------|
| {term} | {definition in context of this project} |
```
