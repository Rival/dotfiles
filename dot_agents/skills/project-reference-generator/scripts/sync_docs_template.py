#!/usr/bin/env python3
"""
Documentation Sync Pipeline for project-reference

Tracks codebase changes and identifies which documentation needs updating.
Copy this file to your project's .claude/skills/project-reference/scripts/sync_docs.py

Usage:
    python scripts/sync_docs.py              # Detect changes
    python scripts/sync_docs.py --status     # Show pending updates
    python scripts/sync_docs.py --verify     # Verify docs match code
    python scripts/sync_docs.py --missing    # Find undocumented code
    python scripts/sync_docs.py --apply N    # Generate update prompt for task N
    python scripts/sync_docs.py --clear      # Clear pending updates
    python scripts/sync_docs.py --log "msg"  # Append entry to changelog
    python scripts/sync_docs.py --check-version  # Check generator template version
"""

import argparse
import json
import subprocess
import re
from dataclasses import dataclass, asdict
from datetime import datetime
from fnmatch import fnmatch
from pathlib import Path
from typing import List, Dict, Optional


CURRENT_GENERATOR_VERSION = 2
MAX_DIFF_LINES_PER_FILE = 200
MAX_DIFF_LINES_TOTAL = 500


@dataclass
class PendingUpdate:
    doc_file: str
    changed_files: List[str]
    reason: str
    commit: str
    priority: str
    diff_summary: str = ""
    status: str = "pending"


class DocumentationSyncPipeline:
    def __init__(self, repo_root: Path, skill_root: Path):
        self.repo_root = repo_root
        self.skill_root = skill_root
        self.state_file = skill_root / "sync-state.json"
        self.mapping_file = skill_root / "docs/domain-mapping.json"
        self.config_file = skill_root / "config.yaml"
        self.changelog_file = skill_root / "references/changelog.md"
        self.refs_dir = skill_root / "references"
        self.config = self._load_config()
        self.state = self._load_state()
        self.mappings = self._load_mappings()
        self.has_git = self._check_git()

    def _load_config(self) -> dict:
        """Load config.yaml if present. Uses safe YAML subset (no PyYAML dependency)."""
        if not self.config_file.exists():
            return {}
        try:
            import yaml
            return yaml.safe_load(self.config_file.read_text()) or {}
        except ImportError:
            # Fallback: parse simple key-value YAML without PyYAML
            config = {}
            for line in self.config_file.read_text().splitlines():
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if ":" in line and not line.startswith("-"):
                    key, _, val = line.partition(":")
                    val = val.strip().strip('"').strip("'")
                    if val:
                        try:
                            config[key.strip()] = int(val)
                        except ValueError:
                            config[key.strip()] = val
            return config

    def _check_git(self) -> bool:
        result = subprocess.run(
            ["git", "rev-parse", "--is-inside-work-tree"],
            capture_output=True, text=True, cwd=self.repo_root,
        )
        return result.returncode == 0

    def _load_state(self) -> dict:
        if self.state_file.exists():
            return json.loads(self.state_file.read_text())
        return {"last_analyzed_commit": None, "last_analyzed_time": None, "pending_updates": [], "file_mtimes": {}}

    def _load_mappings(self) -> dict:
        if not self.mapping_file.exists():
            print(f"Warning: Mapping file not found: {self.mapping_file}")
            return {"mappings": [], "ignore_patterns": [], "file_extensions": []}
        return json.loads(self.mapping_file.read_text())

    def _save_state(self):
        self.state_file.parent.mkdir(parents=True, exist_ok=True)
        self.state_file.write_text(json.dumps(self.state, indent=2))

    def get_current_commit(self) -> Optional[str]:
        if not self.has_git:
            return None
        result = subprocess.run(["git", "rev-parse", "HEAD"], capture_output=True, text=True, cwd=self.repo_root)
        return result.stdout.strip() if result.returncode == 0 else None

    def _get_tracked_extensions(self) -> List[str]:
        return self.mappings.get("file_extensions", []) or [".py", ".js", ".ts", ".cs", ".go", ".rs", ".java", ".kt"]

    def _scan_files_by_mtime(self) -> List[str]:
        """Fallback change detection for non-git directories using file modification times."""
        import glob as g
        old_mtimes = self.state.get("file_mtimes", {})
        new_mtimes = {}
        changed = []
        extensions = self._get_tracked_extensions()

        for ext in extensions:
            for filepath in g.glob(str(self.repo_root / "**" / f"*{ext}"), recursive=True):
                rel = str(Path(filepath).relative_to(self.repo_root))
                if self.should_ignore_file(rel):
                    continue
                mtime = Path(filepath).stat().st_mtime
                new_mtimes[rel] = mtime
                if rel not in old_mtimes or old_mtimes[rel] < mtime:
                    changed.append(rel)

        self.state["file_mtimes"] = new_mtimes
        return changed

    def get_changed_files(self, since_commit: Optional[str] = "HEAD~10") -> List[str]:
        if not self.has_git:
            return self._scan_files_by_mtime()

        if not since_commit:
            result = subprocess.run(["git", "log", "--format=%H", "-10"], capture_output=True, text=True, cwd=self.repo_root)
            if result.returncode != 0:
                return []
            commits = result.stdout.strip().split('\n')
            since_commit = commits[-1] if commits and commits[0] else "HEAD~10"

        result = subprocess.run(["git", "diff", "--name-only", since_commit, "HEAD"], capture_output=True, text=True, cwd=self.repo_root)
        if result.returncode != 0:
            return []
        return [f for f in result.stdout.strip().split('\n') if f]

    def _get_file_diffs(self, files: List[str], since_commit: Optional[str]) -> Dict[str, str]:
        """Get diffs for changed files. Returns {filepath: diff_text}. Empty in mtime mode."""
        if not self.has_git or not since_commit:
            return {}
        diffs = {}
        for filepath in files:
            result = subprocess.run(
                ["git", "diff", since_commit, "HEAD", "--", filepath],
                capture_output=True, text=True, cwd=self.repo_root,
            )
            if result.returncode == 0 and result.stdout.strip():
                lines = result.stdout.strip().split('\n')
                if len(lines) > MAX_DIFF_LINES_PER_FILE:
                    lines = lines[:MAX_DIFF_LINES_PER_FILE]
                    lines.append(f"... truncated ({len(result.stdout.strip().split(chr(10)))} total lines)")
                diffs[filepath] = '\n'.join(lines)
        return diffs

    def _build_diff_summary(self, changed_files: List[str], file_diffs: Dict[str, str]) -> str:
        """Concatenate per-file diffs into a single summary, respecting total line limit."""
        if not file_diffs:
            return ""
        parts = []
        total_lines = 0
        for filepath in changed_files:
            diff = file_diffs.get(filepath)
            if not diff:
                continue
            diff_lines = diff.split('\n')
            remaining = MAX_DIFF_LINES_TOTAL - total_lines
            if remaining <= 0:
                parts.append(f"--- {filepath} ---\n... skipped (line budget exhausted)")
                break
            if len(diff_lines) > remaining:
                diff_lines = diff_lines[:remaining]
                diff_lines.append("... truncated")
            parts.append(f"--- {filepath} ---\n" + '\n'.join(diff_lines))
            total_lines += len(diff_lines)
        return '\n\n'.join(parts)

    def should_ignore_file(self, file_path: str) -> bool:
        ext = Path(file_path).suffix
        extensions = self.mappings.get("file_extensions", [])
        if extensions and ext not in extensions:
            return True
        for pattern in self.mappings.get("ignore_patterns", []):
            if fnmatch(file_path, pattern) or fnmatch(Path(file_path).name, pattern):
                return True
        return False

    def match_files_to_docs(self, changed_files: List[str]) -> Dict[str, List[str]]:
        affected_docs = {}
        for changed_file in changed_files:
            if self.should_ignore_file(changed_file):
                continue
            for mapping in self.mappings.get("mappings", []):
                pattern = mapping["code_pattern"]
                doc_file = mapping["doc_file"]
                if not doc_file:
                    continue
                if pattern.endswith("/**"):
                    prefix = pattern[:-3]
                    if changed_file.startswith(prefix):
                        affected_docs.setdefault(doc_file, []).append(changed_file)
                elif "*" in pattern:
                    if fnmatch(changed_file, pattern):
                        affected_docs.setdefault(doc_file, []).append(changed_file)
                else:
                    if changed_file == pattern:
                        affected_docs.setdefault(doc_file, []).append(changed_file)
        return affected_docs

    def generate_update_tasks(self, affected_docs: Dict[str, List[str]], current_commit: str, file_diffs: Optional[Dict[str, str]] = None) -> List[PendingUpdate]:
        priority_map = {m["doc_file"]: m.get("priority", "medium") for m in self.mappings.get("mappings", []) if m["doc_file"]}
        tasks = []
        for doc_file, changed_files in affected_docs.items():
            description = next((m.get("description", "Unknown") for m in self.mappings.get("mappings", []) if m["doc_file"] == doc_file), "Unknown")
            diff_summary = self._build_diff_summary(changed_files, file_diffs or {})
            tasks.append(PendingUpdate(
                doc_file=doc_file, changed_files=changed_files,
                reason=f"{len(changed_files)} file(s) changed in {description}",
                commit=current_commit, priority=priority_map.get(doc_file, "medium"),
                diff_summary=diff_summary,
            ))
        tasks.sort(key=lambda t: {"high": 0, "medium": 1, "low": 2}.get(t.priority, 3))
        return tasks

    def run(self, dry_run: bool = False) -> List[PendingUpdate]:
        current_commit = self.get_current_commit()
        checkpoint = current_commit or datetime.now().isoformat()

        since_commit = self.state.get("last_analyzed_commit")
        changed_files = self.get_changed_files(since_commit)
        if not changed_files:
            print("No changes detected since last analysis")
            return []

        interesting = [f for f in changed_files if not self.should_ignore_file(f)]
        file_diffs = self._get_file_diffs(interesting, since_commit)
        affected_docs = self.match_files_to_docs(interesting)

        if not affected_docs:
            print("Changes detected, but no documentation affected")

        tasks = self.generate_update_tasks(affected_docs, checkpoint, file_diffs) if affected_docs else []
        if current_commit:
            self.state["last_analyzed_commit"] = current_commit
        self.state["last_analyzed_time"] = datetime.now().isoformat()
        self.state["pending_updates"].extend([asdict(t) for t in tasks])
        if not dry_run:
            self._save_state()
        return tasks

    def show_status(self):
        current = self.get_current_commit()
        last = self.state.get("last_analyzed_commit")
        pending = self.state.get("pending_updates", [])
        mode = "git" if self.has_git else "mtime"
        print(f"Documentation Sync Status (mode: {mode})")
        if self.has_git:
            print(f"Current commit: {current[:8] if current else 'N/A'}...")
            print(f"Last analyzed: {last[:8] if last else 'Never'}...")
        else:
            last_time = self.state.get("last_analyzed_time")
            print(f"Last analyzed: {last_time or 'Never'}")
            tracked = len(self.state.get("file_mtimes", {}))
            print(f"Tracked files: {tracked}")
        if not pending:
            print("No pending documentation updates")
            return
        print(f"\nPending updates: {len(pending)} docs\n")
        for i, update in enumerate(pending):
            print(f"  [{i + 1}] {update['doc_file']} ({update.get('priority', 'medium')})")
            print(f"      {update['reason']}")

    def clear_pending(self):
        self.state["pending_updates"] = []
        self._save_state()
        print("Cleared all pending updates")

    def apply_update(self, index: int):
        pending = self.state.get("pending_updates", [])
        if index < 0 or index >= len(pending):
            print(f"Invalid index: {index}")
            return None
        update = pending[index]
        diff_summary = update.get("diff_summary", "")

        prompt = f"Update documentation: {update['doc_file']}\n\nChanged files:\n"
        for f in update["changed_files"]:
            prompt += f"- {f}\n"
        prompt += f"\nReason: {update['reason']}\nCheckpoint: {update['commit']}\n"

        if diff_summary:
            prompt += "\n## Code Diff\n\n"
            prompt += diff_summary
            prompt += "\n\n## Instructions\n\n"
            prompt += "The diff above shows exactly what changed in the code.\n"
            prompt += "1. Read the existing doc file and identify which sections are affected by these changes.\n"
            prompt += "2. Update ONLY the affected sections. Do NOT rewrite sections unrelated to the diff.\n"
            prompt += "3. If the diff adds new classes/methods/fields, add them to the relevant tables.\n"
            prompt += "4. If the diff removes or renames symbols, update or remove them from the doc.\n"
            prompt += "5. If the diff changes behavior/flow, update the Flow or Architecture sections.\n"
        else:
            prompt += "\n## Instructions\n\n"
            prompt += "No diff available (non-git directory or first run).\n"
            prompt += "Read the changed files listed above and the existing doc, then update the doc to reflect current code.\n"

        prompt += "\nRules: No emojis in headers. English headers. Tables over prose. Method signatures only."

        print("=" * 60)
        print("UPDATE PROMPT")
        print("=" * 60)
        print(prompt)
        return prompt

    def verify_docs(self) -> List[Dict]:
        issues = []
        for mapping in self.mappings.get("mappings", []):
            doc_file = mapping["doc_file"]
            if not doc_file:
                continue
            full_path = self.refs_dir / doc_file
            if not full_path.exists():
                continue
            try:
                doc_content = full_path.read_text()
            except:
                continue
            class_refs = set(re.findall(r'`([A-Z][a-zA-Z0-9_]+)`', doc_content))
            code_files = self._find_code_files(mapping["code_pattern"])
            for cls in class_refs:
                found = any(f"class {cls}" in (self.repo_root / cf).read_text() for cf in code_files if (self.repo_root / cf).exists())
                if not found:
                    issues.append({"doc_file": doc_file, "type": "missing_class", "reference": cls})
        return issues

    def find_missing_docs(self) -> List[Dict]:
        missing = []
        for mapping in self.mappings.get("mappings", []):
            doc_file = mapping["doc_file"]
            if not doc_file:
                continue
            if not (self.refs_dir / doc_file).exists():
                missing.append({"doc_file": doc_file, "description": mapping.get("description", "Unknown"), "status": "missing"})
        return missing

    def _find_code_files(self, pattern: str) -> List[str]:
        import glob as g
        if pattern.endswith("/**"):
            base = self.repo_root / pattern[:-3]
            if base.exists():
                result = []
                for ext in self.mappings.get("file_extensions", []):
                    result.extend(g.glob(str(base / "**" / f"*{ext}"), recursive=True))
                return [str(Path(f).relative_to(self.repo_root)) for f in result]
        elif "*" in pattern:
            return g.glob(pattern, root_dir=self.repo_root, recursive=True)
        else:
            return [pattern] if (self.repo_root / pattern).exists() else []
        return []


    def append_changelog(self, entry: str):
        """Append an entry to references/changelog.md under today's date."""
        today = datetime.now().strftime("%Y-%m-%d")
        if not self.changelog_file.exists():
            self.changelog_file.parent.mkdir(parents=True, exist_ok=True)
            self.changelog_file.write_text("# Changelog\n\nDocumentation update history.\n\n")

        content = self.changelog_file.read_text()
        header = f"## {today}"

        if header in content:
            # Append under existing date header
            idx = content.index(header) + len(header)
            # Find end of line after header
            nl = content.index("\n", idx)
            content = content[:nl + 1] + f"- {entry}\n" + content[nl + 1:]
        else:
            # Insert new date section after the preamble
            marker = "<!-- Add new entries at the top -->"
            if marker in content:
                idx = content.index(marker) + len(marker)
                content = content[:idx] + f"\n\n{header}\n\n- {entry}\n" + content[idx:]
            else:
                content += f"\n{header}\n\n- {entry}\n"

        self.changelog_file.write_text(content)
        print(f"Changelog: {entry}")

    def check_version(self):
        """Check if config.yaml generator_version matches current template version."""
        doc_version = self.config.get("generator_version")
        if doc_version is None:
            print(f"Warning: No generator_version in config.yaml")
            print(f"Current template version: {CURRENT_GENERATOR_VERSION}")
            print("Consider regenerating docs or adding generator_version to config.yaml")
            return False
        if int(doc_version) < CURRENT_GENERATOR_VERSION:
            print(f"Docs outdated: generated with v{doc_version}, current templates are v{CURRENT_GENERATOR_VERSION}")
            print("Consider running /ref-update with 'Regenerate level' to refresh docs with latest templates.")
            return False
        elif int(doc_version) > CURRENT_GENERATOR_VERSION:
            print(f"Warning: docs version ({doc_version}) is newer than sync script ({CURRENT_GENERATOR_VERSION})")
            print("You may need to update the sync script from the generator skill.")
            return False
        print(f"Template version OK: v{CURRENT_GENERATOR_VERSION}")
        return True


def main():
    parser = argparse.ArgumentParser(description="Documentation Sync Pipeline")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--status", action="store_true")
    parser.add_argument("--clear", action="store_true")
    parser.add_argument("--apply", type=int, metavar="INDEX")
    parser.add_argument("--verify", action="store_true")
    parser.add_argument("--missing", action="store_true")
    parser.add_argument("--log", type=str, metavar="ENTRY", help="Append changelog entry")
    parser.add_argument("--check-version", action="store_true", help="Check generator template version")
    parser.add_argument("--repo", type=Path, default=None)
    parser.add_argument("--skill", type=Path, default=None)
    args = parser.parse_args()

    repo_root = args.repo or Path.cwd().parent.parent.parent  # .claude/skills/project-reference -> repo root
    skill_root = args.skill or Path.cwd()

    pipeline = DocumentationSyncPipeline(repo_root, skill_root)

    if args.status:
        pipeline.show_status()
    elif args.clear:
        pipeline.clear_pending()
    elif args.verify:
        issues = pipeline.verify_docs()
        if not issues:
            print("All docs match code!")
        else:
            print(f"Found {len(issues)} issues:")
            for i in issues:
                print(f"  {i['doc_file']}: missing {i['type']} `{i['reference']}`")
    elif args.missing:
        missing = pipeline.find_missing_docs()
        if not missing:
            print("All mapped code is documented!")
        else:
            print(f"Missing {len(missing)} docs:")
            for m in missing:
                print(f"  {m['doc_file']} - {m['description']}")
    elif args.log:
        pipeline.append_changelog(args.log)
    elif args.check_version:
        pipeline.check_version()
    elif args.apply is not None:
        pipeline.apply_update(args.apply)
    else:
        tasks = pipeline.run(dry_run=args.dry_run)
        if tasks:
            print(f"Found {len(tasks)} docs needing updates:")
            for i, t in enumerate(tasks):
                print(f"  [{i+1}] {t.doc_file} - {t.reason}")


if __name__ == "__main__":
    main()
