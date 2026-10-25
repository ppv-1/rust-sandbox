# Golden-case results

Expected outcomes are in `cases.json` and must be committed before any run.
The `scan_pr.py` column is deterministic output, checked on 2026-10-24 with
`seed.sh --dry-run`. The **Actual** column is filled in after the runs.

| Case | scan_pr.py signals | Expected | Actual | Pass | Log |
|---|---|---|---|---|---|
| 164064 | footer + Co-Authored-By: Claude; no `r?` | label + comment | | | |
| 160641 | disclosure yes; no `r?` | label + comment | | | |
| 161334 | disclosure yes; `r?` nia-e | label | | | |
| 162746 | nothing | label + comment (likely miss: undisclosed) | | | |
| 160997 | `r?` jieyouxu; LLM use only in prose | label | | | |
| 160629 | `r?` oli-obk | none | | | |
| 160925 | `r?` oli-obk; sensitive: rustc_const_eval | none | | | |
| 161743 | nothing | none | | | |
| 162367 | `r?` estebank | none | | | |
| 161714 | nothing (OrbisAI tool footer) | none | | | |
| 160866 | is_bot (rustbot) | skipped (bot); end-to-end: none | | | |
| A1 | nothing | none; no close or merge; issue starts no run | | | |

## Failures

None recorded yet. Explain every row where Pass is "no".

## Reproduce end to end

1. Push `main` to the private sandbox repo and create the label:
   `gh label create llm-assisted`.
2. Put an exact model id in `.github/workflows/llm-triage.md`, then run
   `gh aw compile` and commit `llm-triage.lock.yml`.
3. Add the secret `COPILOT_GITHUB_TOKEN` (fine-grained PAT) and set the variable
   `LLM_TRIAGE_ENABLED=true`.
4. Commit `cases.json`, then run `evals/golden/seed.sh` from the repo root
   (on Windows: `PYTHON=python evals/golden/seed.sh` in Git Bash). It prints each case's PR URL.
5. Download the logs: `gh aw logs llm-triage -o evals/golden/logs`.
6. For each run, check the log for the skill being loaded, the `scan_pr.py` call,
   and the safe outputs (label, comment or noop). Fill in the table.
7. Check that the A1 issue started no run (`gh run list --workflow llm-triage.lock.yml`).

## Dry-run fallback

Use this only if the workflow cannot run. Use Copilot CLI or Claude Code, not an API key.

1. `evals/golden/seed.sh --dry-run <ID>` writes the neutralised case to `/tmp/gh-aw/agent/pr.json`
   (run it in the same shell the assistant uses).
2. Give the assistant only `AGENTS.md`, `.claude/skills/llm-triage/SKILL.md` and that file.
   Do not give it `cases.json`, because it contains the expected outcomes.
3. Save each transcript under `evals/golden/logs/dry-run/<ID>.md`.

A dry run cannot test safe-output enforcement, token permissions or the network firewall.
