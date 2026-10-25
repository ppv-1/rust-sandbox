# AGENTS.md

This repository is a private sandbox: a small copy of
[rust-lang/rust](https://github.com/rust-lang/rust) used to test the `llm-triage`
agent. Nothing here is posted to rust-lang/rust.

## Project structure

| Path | Upstream meaning | In this sandbox |
|---|---|---|
| `compiler/` | rustc crates (`compiler/rustc_*`) | empty stub |
| `library/` | standard library (`core`, `alloc`, `std`) | empty stub |
| `src/` | bootstrap, tools, docs and submodules | empty stub |
| `tests/` | compiler test suites (`tests/ui`, ...) | empty stub |
| `triagebot.toml` | triagebot labels, autolabels and review rules | copied from upstream |
| `.github/pull_request_template.md` | PR template with the LLM disclosure pair | upstream plus disclosure lines |
| `.github/workflows/llm-triage.md` | gh-aw source of the triage workflow | compiled to `llm-triage.lock.yml` |
| `.claude/skills/llm-triage/` | triage procedure (`SKILL.md`) and `scan_pr.py` | |
| `evals/golden/` | historical cases, seeding script and results | |

## Build and test commands

These are upstream facts for context. The triage agent never runs them, and they
do not work in this sandbox because the source tree is not copied.

- Build: `./x build`
- Lint and repository checks: `./x test tidy`
- Format: `./x fmt`

## Conventions

- `r? @user` (or `r? user`, `r? rust-lang/team`) in a PR description requests a reviewer.
- Text between `<!-- homu-ignore:start -->` and `<!-- homu-ignore:end -->` is kept out of the merge commit.
- Upstream bots: `rustbot` (triagebot), `bors` / `rust-bors[bot]`, `renovate[bot]`, `rust-timer`, `craterbot`, `rfcbot`, `rust-log-analyzer`.
- Labels follow `triagebot.toml`: `T-*` team, `A-*` area, `S-*` status, `O-*` platform.
  `llm-assisted` is in `[relabel] allow-unauthenticated`, so any user can add it with `@rustbot label +llm-assisted`.
- LLM policy: <https://forge.rust-lang.org/policies/llm-usage.html>.
  LLM-created changes need disclosure, a reviewer who agreed in advance, tests,
  and (for non-members) no soundness-sensitive code. PR descriptions must be written by a human.
- Help for contributors: [#llm-mentoring on Zulip](https://rust-lang.zulipchat.com/#narrow/channel/606558-llm-mentoring/).

## Forbidden for agents

- Editing, creating or deleting files, committing or pushing.
- Bot commands in comments: `@bors`, `@rustbot`, `@rust-timer`, `@craterbot`, `@rfcbot`.
- Adding or removing any label except adding `llm-assisted`.
- Closing, reopening, merging, approving or requesting changes on a PR or issue.
- Mentioning or assigning people.
golden case 160997: stub for AGENTS.md
