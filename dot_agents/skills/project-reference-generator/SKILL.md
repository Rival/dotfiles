---
name: project-reference-generator
description: Generate project-reference documentation for any codebase. Analyzes repository structure, identifies tech stack, domains, key classes, and creates a complete .claude/skills/project-reference/ with L1-L3 docs, index, sync pipeline, and domain mappings. Use when user says "create project reference", "generate project docs", "document this codebase", "create reference for this repo", "init project-reference", or when starting work on a repo without existing project-reference.
---

# Project Reference Generator

Generate a complete `project-reference` skill for any repository. Produces multi-level LLM-friendly documentation (L1 architecture, L2 patterns, L3 domains).

## Output Structure

```
.claude/skills/project-reference/
├── SKILL.md                          # Entry point
├── config.yaml                       # Scanner config & generator version
├── sync-state.json                   # Sync tracking
├── references/
│   ├── index.md                      # Task -> file:section
│   ├── L1-architecture.md            # Tech stack, modules, data flow
│   ├── code-architecture.md          # DI, services, patterns
│   ├── L2-project-structure.md       # Folder tree, assemblies
│   ├── L2-code-patterns.md           # Naming, conventions, idioms
│   ├── cheatsheet.md                 # Quick copy-paste snippets
│   ├── glossary.md                   # Domain terms
│   ├── changelog.md                  # Update history
│   └── L3-domains/{domain}.md        # Per-domain details
├── docs/
│   ├── standards.md                  # Doc standards
│   ├── domain-mapping.json           # Code path -> doc mapping
│   └── plans/
│       ├── l3-domain-reference-template.md
│       └── l3-domain-workflow.md
└── scripts/
    └── sync_docs.py                  # Sync pipeline
```

## Workflow

### Phase 1: Discovery

Use Task tool with `Explore` agent to gather:

```
[ ] Language, framework, versions (package.json / Cargo.toml / .csproj / go.mod / pyproject.toml)
[ ] Build system & commands
[ ] Folder structure (2-3 levels)
[ ] Entry point(s)
[ ] DI / service pattern
[ ] Key base classes / interfaces
[ ] Module / assembly / package structure
[ ] External services (DB, API, CDN, auth)
[ ] Test framework & location
[ ] Config format & location
[ ] Domain list with key classes per domain
```

### Phase 2: Generate L1 — Architecture

See [L1 template](references/L1-template.md).

### Phase 3: Generate L2 — Structure & Patterns

Generate in parallel:
- `L2-project-structure.md` — folder tree, modules, dependencies
- `L2-code-patterns.md` — naming, conventions, async, error handling
- `code-architecture.md` — DI, services, state management
- `cheatsheet.md` — common operations as `| Task | Code |` table
- `glossary.md` — domain terms

See [L2 templates](references/L2-templates.md).

### Phase 4: Generate L3 — Domains

For each domain, create `L3-domains/{domain}.md` using Task tool with general-purpose agent.

See [L3 template](references/L3-template.md).

**Rules:** No emojis in headers. English headers. Tables over prose. Method signatures only. ASCII diagrams. Cross-references.

### Phase 5: Generate Index & SKILL.md

See [meta templates](references/meta-templates.md).

### Phase 6: Generate Infrastructure

- `domain-mapping.json` — code path -> doc file mapping
- `config.yaml` — copy from [config template](references/config-template.yaml), customize scan paths/extensions for the project, set `generator_version`
- `scripts/sync_docs.py` — copy from [sync template](scripts/sync_docs_template.py)
- `references/changelog.md` — copy from [changelog template](references/changelog-template.md)
- `docs/standards.md`, `docs/plans/` — doc standards and templates

### Phase 7: Verify

```
[ ] All files non-empty
[ ] Internal links resolve
[ ] Index covers all domains
[ ] SKILL.md lists all docs
[ ] domain-mapping.json covers code paths
[ ] No emojis in headers
[ ] English-only headers
```

## Execution Strategy

After Phase 1 discovery, Phases 2-4 can run **in parallel** using Task tool:
- Phase 2: one agent for L1
- Phase 3: one agent for L2 files
- Phase 4: one agent per domain (or batch)
- Phase 5-6: sequential after 2-4 complete

## Stack Detection Hints

| Stack | Key Files | Look For |
|-------|-----------|----------|
| Unity/C# | `*.asmdef`, `ProjectSettings/` | `MonoBehaviour`, `ScriptableObject`, `IService.Get<T>()` |
| Python | `pyproject.toml`, `setup.py` | `__init__.py`, `__main__.py`, Django/Flask/FastAPI |
| TypeScript | `package.json`, `tsconfig.json` | Next.js, React, NestJS, Express |
| Go | `go.mod`, `cmd/` | `internal/`, interfaces, `Makefile` |
| Rust | `Cargo.toml`, `src/lib.rs` | traits, `mod.rs`, workspace |
| Java/Kotlin | `pom.xml`, `build.gradle` | Spring Boot, `@Service`, `@Controller` |

## Documentation Standards

| Rule | Do | Don't |
|------|-----|-------|
| Structure | Tables | Paragraphs |
| Code | Method signatures | Full implementations |
| Diagrams | ASCII art | Images |
| Headers | English, no emoji | `# Domain 🎵` |
| Paths | Backticks: `src/` | Plain text |
| Links | Cross-reference | Duplicate info |
