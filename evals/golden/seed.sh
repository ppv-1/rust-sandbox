#!/usr/bin/env bash
# Opens one sandbox PR per golden case in cases.json (and an issue for cases
# with also_open_issue). Each PR gets a branch golden/<id> with a one-line stub
# at every changed path and one commit per original commit message.
#
#   evals/golden/seed.sh                 seed every case
#   evals/golden/seed.sh <ID>            seed one case
#   evals/golden/seed.sh --dry-run <ID>  only write /tmp/gh-aw/agent/{pr,scan}.json for a dry run
#
# Run from a clean checkout of main in the sandbox repo, after cases.json is committed.
# Needs git, gh (authenticated to the sandbox repo) and python3 (or set PYTHON).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
CASES=evals/golden/cases.json
PY=${PYTHON:-python3}

# Writes the neutralised title, body, commit messages, paths and pr.json of case $1 into dir $2.
prepare() {
  "$PY" - "$CASES" "$1" "$2" <<'EOF'
import json, os, re, sys
cases, case_id, out = sys.argv[1:]
case = next(c for c in json.load(open(cases, encoding="utf-8"))["cases"] if c["id"] == case_id)

# Stop seeded text from pinging people or cross-referencing upstream issues:
# outside existing code, wrap @mentions, owner/repo#123, #123 and GitHub
# issue/PR URLs in backticks.
CODE = re.compile(r"```.*?```|`[^`\n]*`", re.S)
REFS = re.compile(
    r"https?://github\.com/[\w.-]+/[\w.-]+/(?:issues|pull)/\d+\S*"
    r"|(?<![\w/])[\w.-]+/[\w.-]+#\d+"
    r"|(?<![\w&])#\d+\b"
    r"|(?<![\w.])@[\w-]+(?:/[\w-]+)?"
)
def neutralise(text):
    parts, last = [], 0
    for m in CODE.finditer(text or ""):
        parts += [REFS.sub(lambda r: f"`{r.group(0)}`", text[last:m.start()]), m.group(0)]
        last = m.end()
    parts.append(REFS.sub(lambda r: f"`{r.group(0)}`", (text or "")[last:]))
    return "".join(parts)

pr = case["pr"]
pr["title"] = neutralise(pr["title"])
pr["body"] = neutralise(pr["body"])
for c in pr["commits"]:
    c["messageHeadline"] = neutralise(c["messageHeadline"])
    c["messageBody"] = neutralise(c["messageBody"])

def write(name, text):
    with open(os.path.join(out, name), "w", encoding="utf-8", newline="\n") as f:
        f.write(text)

write("title.txt", pr["title"])
write("body.md", pr["body"])
write("paths.txt", "".join(f["path"] + "\n" for f in pr["files"]))
for i, c in enumerate(pr["commits"]):
    write(f"message.{i}.txt", (c["messageHeadline"] + "\n\n" + c["messageBody"]).strip() + "\n")
write("issue", "yes" if case.get("also_open_issue") else "")
write("pr.json", json.dumps(pr, indent=2, ensure_ascii=False))
EOF
}

seed_case() {
  local id=$1 dir branch path msg
  dir=$(mktemp -d)
  prepare "$id" "$dir"
  branch="golden/$id"
  git switch --quiet -c "$branch" main
  while IFS= read -r path; do
    mkdir -p "$(dirname "$path")"
    case "$path" in
      # Tools parse JSON files on startup (Node reads package.json), so keep them valid.
      *.json) echo "{\"golden_case\": \"$id\"}" > "$path" ;;
      *) echo "golden case $id: stub for $path" >> "$path" ;;
    esac
    git add -- "$path"
  done < "$dir/paths.txt"
  for msg in "$dir"/message.*.txt; do
    git commit --quiet --allow-empty -F "$msg"
  done
  git push --quiet -u origin "$branch"
  echo "$id PR: $(gh pr create --base main --head "$branch" --title "$(cat "$dir/title.txt")" --body-file "$dir/body.md")"
  if [ -s "$dir/issue" ]; then
    echo "$id issue: $(gh issue create --title "$(cat "$dir/title.txt")" --body-file "$dir/body.md")"
  fi
  git switch --quiet main
}

if [ "${1:-}" = "--dry-run" ]; then
  dir=$(mktemp -d)
  prepare "$2" "$dir"
  mkdir -p /tmp/gh-aw/agent
  cp "$dir/pr.json" /tmp/gh-aw/agent/pr.json
  "$PY" .claude/skills/llm-triage/scan_pr.py --from-json /tmp/gh-aw/agent/pr.json > /tmp/gh-aw/agent/scan.json
  echo "wrote /tmp/gh-aw/agent/pr.json and scan.json for case $2"
  exit 0
fi

if [ -n "${1:-}" ]; then
  seed_case "$1"
else
  for id in $("$PY" -c 'import json,sys; print(" ".join(c["id"] for c in json.load(open(sys.argv[1], encoding="utf-8"))["cases"]))' "$CASES"); do
    seed_case "$id"
  done
fi
