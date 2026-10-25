#!/usr/bin/env python3
"""Deterministic LLM-policy signals for one pull request. No model judgement.

Usage:
  scan_pr.py <PR_NUMBER>         read the PR live with `gh pr view`
  scan_pr.py --from-json <FILE>  read a saved `gh pr view --json` object
                                 (written by the workflow, or by seed.sh --dry-run)

Prints one JSON object to stdout. Standard library only.
"""
import json
import re
import subprocess
import sys

GH_FIELDS = "number,title,body,commits,files,author,labels"

ALLOWED_LABELS = ["llm-assisted"]

# Accounts that open automated PRs upstream. rustbot is a plain User account,
# so GitHub's own is_bot flag does not catch it.
KNOWN_BOTS = {
    "bors", "rust-bors", "rustbot", "renovate", "dependabot",
    "github-actions", "rust-timer", "craterbot", "rfcbot", "rust-log-analyzer",
}

# Soundness-sensitive compiler areas, from upstream rust AGENTS.md ("Soundness").
SENSITIVE_PATHS = [
    r"compiler/rustc_trait_selection/",
    r"compiler/rustc_borrowck/",
    r"compiler/rustc_mir_[^/]+/",
    r"compiler/rustc_const_eval/",
    r"compiler/rustc_middle/src/ty/",
    r"compiler/rustc_codegen_[^/]+/",
]

MARKERS = {
    "claude-code-footer": re.compile(r"Generated with \[?Claude Code\]?", re.I),
    "co-authored-by-llm": re.compile(r"^\s*Co-Authored-By:\s*(Claude|Copilot|Cursor)\b", re.I | re.M),
}

# The yes/no pair in .github/pull_request_template.md (same wording upstream used in Aug 2026).
DISCLOSURE_NO = re.compile(r"^\s*[-*]\s*\[[xX]\]\s*I did not use an LLM", re.M)
DISCLOSURE_YES = re.compile(r"^\s*[-*]\s*\[[xX]\]\s*I used an LLM", re.M)

# `r? @user`, `r? user`, `r? rust-lang/team`, also with the backticks seed.sh adds.
R_QUESTION = re.compile(r"^\s*r\?\s*`?@?([\w-]+(?:/[\w-]+)?)`?", re.M)

HTML_COMMENT = re.compile(r"<!--.*?-->", re.S)


def load_pr(argv):
    if argv and argv[0] == "--from-json":
        with open(argv[1], encoding="utf-8") as f:
            return json.load(f)
    out = subprocess.run(
        ["gh", "pr", "view", argv[0], "--json", GH_FIELDS],
        check=True, capture_output=True, text=True,
    ).stdout
    return json.loads(out)


def scan(pr):
    # Template text lives in HTML comments (including an example `r? <reviewer name>`).
    body = HTML_COMMENT.sub("", pr.get("body") or "")
    commits = pr.get("commits") or []

    said_yes = bool(DISCLOSURE_YES.search(body))
    said_no = bool(DISCLOSURE_NO.search(body))
    disclosure = "yes" if said_yes and not said_no else "no" if said_no and not said_yes else "missing"

    markers = []
    sources = [("body", body)] + [
        ("commit " + (c.get("oid") or "")[:7],
         (c.get("messageHeadline") or "") + "\n\n" + (c.get("messageBody") or ""))
        for c in commits
    ]
    for where, text in sources:
        for name, pattern in MARKERS.items():
            if pattern.search(text):
                markers.append({"marker": name, "where": where})

    r_match = R_QUESTION.search(body)

    author = pr.get("author") or {}
    login = (author.get("login") or "").lower()
    login = login.removeprefix("app/").removesuffix("[bot]")
    is_bot = bool(author.get("is_bot")) or login in KNOWN_BOTS

    paths = [f.get("path", "") for f in pr.get("files") or []]
    sensitive = [p for p in paths if any(re.search(s, p) for s in SENSITIVE_PATHS)]

    labels = [l.get("name") for l in pr.get("labels") or []]

    return {
        "number": pr.get("number"),
        "author": author.get("login"),
        "disclosure_field": disclosure,
        "markers": markers,
        "r_question": r_match.group(1) if r_match else None,
        "is_bot": is_bot,
        "sensitive_paths": sensitive,
        "already_labelled": "llm-assisted" in labels,
        "allowed_labels": ALLOWED_LABELS,
    }


def main(argv):
    if not argv or (argv[0] == "--from-json" and len(argv) < 2):
        sys.exit(__doc__)
    print(json.dumps(scan(load_pr(argv)), indent=2))


if __name__ == "__main__":
    main(sys.argv[1:])
