#!/usr/bin/env bash
# Run the reviewer bench on one or more OpenCode models.
# Usage: bench.sh <out_dir> <provider/model> [<provider/model> ...]
# Score each <out_dir>/<model>.txt against ANSWER_KEY.md yourself; this script only collects replies.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
out="${1:?usage: bench.sh <out_dir> <provider/model>...}"; shift
mkdir -p "$out" && out="$(cd "$out" && pwd)"   # absolute: each run cd's into a temp dir
prompt='Code review. Read PLAN.md, hello.py, test_hello.py and README.md in the current directory. Do NOT edit any file. Check the implementation, the tests and the README against the plan and against claim discipline (no claim may outrun the evidence). Reply in exactly one of two forms: IMPL-APPROVED  or  IMPL-REJECTED followed by numbered blocking defects (file:line + what to change). Nits go under NON-BLOCKING.'
for m in "$@"; do
  work="$(mktemp -d)"; cp -R "$here"/fixture/. "$work"/; rm -rf "$work"/__pycache__
  f="$out/$(echo "$m" | tr / _).txt"
  (
    cd "$work" || exit 1
    start=$(date +%s)
    opencode run -m "$m" "$prompt" > "$f" 2>&1
    echo "secs=$(( $(date +%s) - start ))" >> "$f"
  ) &
  # Concurrent OpenCode starts fail with "database is locked"; stagger them.
  sleep 8
done
wait
for f in "$out"/*.txt; do
  echo "=== $(basename "$f" .txt)"
  sed 's/\x1b\[[0-9;]*m//g' "$f" | sed -nE '/IMPL-(APPROVED|REJECTED)/,$p' | head -40
  grep -E 'database is locked|^secs=' "$f"
done
