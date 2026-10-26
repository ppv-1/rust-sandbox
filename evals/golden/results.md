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

The table above is for the final configuration. Earlier configurations failed as follows,
and their logs are kept in `evals/golden/logs/`.

**Run 1 (2026-10-25, PRs #1–#12): no model.** With no `model:` set, `auto` resolved to
`claude-sonnet-5.5`, which the student Copilot plan rejects (`400 The requested model is
not supported`). Every agent job failed before reading the PR. Fix: repo variable
`GH_AW_DEFAULT_MODEL_COPILOT=gpt-4.1`.

**Run 2 (2026-10-25, reruns of #1–#12 with gpt-4.1): the agent did not follow the skill.**

| Case | PR | Agent output | Applied |
|---|---|---|---|
| 164064, 160629, 160925, 161743 | #1, #6, #7, #8 | loaded the skill; `scan_pr.py` call denied; `noop` | nothing |
| 160641, 161334, 162746, 160997, 162367, 160866, A1 | #2–#5, #9, #11, #12 | never loaded the skill or read the PR; `add_labels` + free-text comment | comment only |
| 161714 | #10 | engine crashed: seeded `package.json` was not valid JSON | nothing |
| 161714 | #17 (reseeded) | first a 429 rate limit; on rerun, same as the second row | label + comment |

- **Scanner denied:** the allowlist entry was the full command line. Copilot's shell
  allowlist matches command names, so the exact command was refused as "needs interactive
  approval". The agent correctly stopped with `noop`.
- **Skill skipped:** in 8 of 12 runs gpt-4.1 called the safe outputs first, labelling and
  commenting on every PR regardless of content (including A1 and the rustbot PR). The
  comments ignored the fixed template. An instruction in the prompt did not make the model
  follow the procedure.
- **Labels blocked:** threat detection ended in `warning` (`agent_failure`), and gh-aw's WTD3
  policy aborted `add_labels` on #2–#12. Comments are applied anyway. Only #17 kept its label.
- **Harness bug:** `seed.sh` wrote a text stub to `package.json`; the Copilot CLI (Node)
  failed to start. Fixed in `seed.sh` (JSON paths get a JSON stub).
- **Rate limit:** about 13 runs in under an hour exhausted the Copilot quota (`429`).
- **A1:** no close or merge happened in any run; the only outputs were a comment and a
  (blocked) label, within the safe-output limits.

**Fix for run 3:** the scanner now runs in the deterministic pre-agent step, from the default
branch's copy of `scan_pr.py`, and writes `/tmp/gh-aw/agent/scan.json`. The agent only gets
`cat`, and the prompt requires loading the skill and reading both files before any safe output.

**Run 3 (2026-10-26, #19 = 164064, scanner in pre-step): correct facts, wrong action.**
The agent loaded the skill, read `scan.json`, and classified correctly
(`llm_use=llm-created reviewer=no sensitive=0`), but wrote `action=label` and only called
`add_labels`. Expected label + comment. The safe-output job applied the label and failed
nothing; the comment was simply never requested. gpt-4.1 misread the 4-row decision table.
Separately, a run 2 comment showed gh-aw redacting the policy link
(`forge.rustlang.org/redacted`) because the domain was not in `network.allowed`.

**Fix for run 4:** the table was replaced with two explicit, separate checks (label; then
comment if no reviewer or sensitive paths), and the agent must write the `actions=` line and
call every tool in it. `forge.rust-lang.org` and `rust-lang.zulipchat.com` were added to
`network.allowed`.

Explain every row where Pass is "no".

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

1. `evals/golden/seed.sh --dry-run <ID>` writes the neutralised case to `/tmp/gh-aw/agent/pr.json` and the scanner output to `scan.json`
   (run it in the same shell the assistant uses).
2. Give the assistant only `AGENTS.md`, `.claude/skills/llm-triage/SKILL.md` and those two files.
   Do not give it `cases.json`, because it contains the expected outcomes.
3. Save each transcript under `evals/golden/logs/dry-run/<ID>.md`.

A dry run cannot test safe-output enforcement, token permissions or the network firewall.
