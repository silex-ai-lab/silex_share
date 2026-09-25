---
name: herdr-fleet-free
description: A zero-cost variant of herdr-agent-fleet. Claude plans and implements, and two free, open-weight models served through OpenCode Zen review the plan and the code as independent judges. The defaults are Xiaomi MiMo-V2.6-Flash and NVIDIA Nemotron 3 Ultra; they ran with no OpenCode credentials configured (checked 2026-09-25), and a bundled bench shows how they were picked and re-checks the choice. Both gates are unanimous across all three seats. Only for public or non-sensitive code, because these free endpoints may log prompts or use them for training. Use when the user wants the Herdr multi-agent review fleet without paying for DeepSeek or Codex, asks for "free" or "open-source" reviewers, or wants to re-pick the free reviewer models.
---

# herdr-fleet-free: Claude + two free open-weight reviewers

This is **herdr-agent-fleet with a different roster**. The workflow is that
skill's Steps 1–9 and its safety rules: plan in a file, a unanimous plan gate,
a recorded review base, a unanimous code gate on the current diff, and a run
log in the changed repo. Load `herdr-agent-fleet` (and Herdr's own skill,
`herdr --skill`) before you start. This file records only what differs.

## Roster

| Seat | Runs as | Job |
|---|---|---|
| **claude** | this agent, calling pane | Owns the plan, implements, resolves splits, casts a written vote |
| **reviewer-mimo** | `--kind opencode -- -m opencode/mimo-v2.6-flash-free` | Reviews plan and diff |
| **reviewer-nemotron** | `--kind opencode -- -m opencode/nemotron-3-ultra-free` | Reviews plan and diff |

**Claude implements; the reviewers do not write code.** In herdr-agent-fleet,
DeepSeek both reviews and codes. Here both free seats stay independent
judges, which is the point of having them. Change this only if the user asks.

Three seats, so Step 6 (routine mid-work questions) has a majority. The plan
gate and code gate still need all three.

## The data rule (read this first)

Per the [OpenCode Zen docs](https://opencode.ai/docs/zen/), checked 2026-09-25:
- MiMo-V2.6-Flash Free: "During its free period, collected data may be used to
  improve the model."
- Nemotron 3 Ultra Free: trial access. Use is logged for security purposes and
  to improve NVIDIA's products; the docs say the logged data is not linked to
  your identity.

The Zen docs also say, for Nemotron 3 Ultra Free: "Trial use only — do not
submit personal or confidential data."

So the rule is absolute: **never send personal or confidential data to these
seats, whatever the user consents to.** In practice, run this fleet only on
public repos, or on material that is already public or plainly non-sensitive
(a toy program, a public fixture). For anything else, use a local model, or
herdr-agent-fleet's paid seats after checking each vendor's own retention
terms. Paid does not mean zero-retention: the same Zen page says OpenAI and
Anthropic API requests are retained for 30 days. The "Fixtures beat access" rule from
herdr-agent-fleet applies twice over here. Never let these seats read
`~/.claude`, `~/.codex`, credentials, or anything outside the target repo.

## Why these two models (bench, 2026-09-25)

The Zen docs listed nine free models on 2026-09-25. `opencode models`
(opencode 1.18.30) offered seven of them:

- **Open-weight, so benched:** MiMo-V2.6-Flash (Xiaomi, MIT), Nemotron 3 Ultra
  and Nemotron 3.5 Lightning (NVIDIA, OpenMDW), and Ling 3.0 Flash Fin
  (inclusionAI).
- **Not considered:** Big Pickle and Space Bunny (origin unknown, weights
  not public), and Muse Spark. The docs say Muse Spark's free tier trades
  your prompts and completions for training future Meta models, which the
  data rule already excludes.
- **In the docs but not usable here:** MiMo-V2.5 Free and Jev 1.13 Free. Both
  were missing from `opencode models`, and `opencode run -m opencode/<id>`
  failed with a server error. MiMo-V2.5 would also share a family with
  MiMo-V2.6.

Each candidate reviewed `bench/fixture/`: a hello-world program with five
seeded defects plus three look-suspicious-but-correct traps. The answer key is
`bench/ANSWER_KEY.md`.

| Model | Defects found (of 5) | False positives | Verdict format | Time |
|---|---|---|---|---|
| **mimo-v2.6-flash-free** | **5**; the only one that ran code to reproduce the hardest bug | 0 | clean | 42 s |
| **nemotron-3-ultra-free** | 4 (missed B) | 0 | clean | 23 s |
| ling-3.0-flash-fin-free | 4 (missed B), **and called B correct** | 0 | clean | 11 s |
| nemotron-3.5-lightning-free | 4 | 0 | **no clean verdict**; printed its reasoning and trailed off | 286 s |

One fixture, one date. This is a first cut, not a general ranking of these
models. The raw replies are not shipped with the skill; `bench/bench.sh`
reproduces the run.

On a trivial three-bug version (not shipped), all four found 3/3 on the same date, so that version did
not separate them. The pick is the top scorer, plus the runner-up from a
**different model family**, so the two seats don't share blind spots. Ling
tied Nemotron 3 Ultra on count, but an asserted wrong claim is worse than a
miss.

## Preflight

```bash
test "${HERDR_ENV:-}" = 1 || echo "not inside Herdr: stop"
opencode --version
opencode models | grep -E 'opencode/(mimo-v2.6-flash-free|nemotron-3-ultra-free)$'
```

On 2026-09-25 both models ran with `opencode auth list` showing 0 credentials
and no `OPENCODE_API_KEY`, including under empty `XDG_*` directories. That was
opencode 1.18.30. If a run now asks for a Zen sign-in, the free tier's terms
have changed. Tell the user; do not sign in on their behalf.

**Free models are "available for a limited time"** (Zen docs). If either
line is missing from `opencode models`, the seat is gone. Do not silently
substitute one. Re-run the bench on the remaining open-weight free models:

```bash
~/.claude/skills/herdr-fleet-free/bench/bench.sh <scratch>/bench \
  opencode/<candidate-1> opencode/<candidate-2> ...
```

Score the replies against `bench/ANSWER_KEY.md`. Before publishing a new
pick, re-check this file's claims (model ids, data-usage terms, the
candidate list) against the Zen docs, and date the check. Propose the replacement to
the user and record the roster change in the run log (herdr-agent-fleet's
roster rule).

## Differences in mechanics

**1. Stagger OpenCode starts by several seconds.** Two OpenCode processes
starting together can fail with `Error: Unexpected error / database is locked`
(OpenCode's local SQLite). Start `reviewer-mimo`, wait for
`herdr agent wait`, then start `reviewer-nemotron`. The same applies to
back-to-back `opencode run` calls. The bench sleeps 8 s between them.

```bash
herdr agent start reviewer-mimo     --kind opencode --pane <paneA> -- -m opencode/mimo-v2.6-flash-free
herdr agent wait  reviewer-mimo --timeout 60000
herdr agent start reviewer-nemotron --kind opencode --pane <paneB> -- -m opencode/nemotron-3-ultra-free
herdr agent wait  reviewer-nemotron --timeout 60000
```

**2. Both seats are OpenCode, so both need file output.** OpenCode renders on
the alternate screen, and long replies do not reach Herdr's scrollback (see
herdr-agent-fleet Step 4). Put in every review prompt: "Write your complete
reply verbatim to `<scratch>/<seat>-<gate>-r<N>.md`". Use a scratch dir
outside the target repo, and a different file per seat and round. Read the
file, not the pane.

**3. Expect a permission dialog per seat** for writing outside its cwd.
"Allow once" is right for a scratch dir. The two-stage dialog and
`herdr pane send-keys <pane> enter` notes from herdr-agent-fleet apply.

**4. Send the byte-identical prompt to both seats**, with only the
output filename differing. Send to the second seat after the first has
visibly received its prompt; the stagger rule covers prompt submission less
strictly than startup, but a read-back per seat costs nothing.

**5. Budget time for the free tier.** Seat latency varies more than on paid
endpoints, and there may be rate limits. A `timeout` from `agent prompt
--wait` still means "check `agent get`", not "failed".

**6. Answer permission dialogs by path, not by habit.** Approve only the
scratch paths you gave the seat, such as the review-output dir or a read-only
copy of the source. Reject anything else. In one run, MiMo asked for an
unrelated `/tmp/...` directory in the middle of a review. After a rejection,
OpenCode ends the turn. Send a short prompt saying what was rejected and why,
and ask it to finish the same review.

Match the highlighted option with `LC_ALL=C grep -a`. The ANSI frame
contains non-UTF-8 bytes, and macOS `/usr/bin/grep` under a UTF-8 locale
matches nothing in it. Re-read after each key: the frame can take a few
seconds to redraw, and a stale read shows the previous highlight.

**7. A short verdict may skip the file.** Nemotron sometimes replies with
just the verdict token and does not write the file. Say "you MUST write the
file even if the reply is one line; the reply does not count until the file
exists". That instruction worked every time after it was added.

**8. Don't hand these seats images.** Give text: the diff, probe results,
command output. Neither seat's image input was tested here.

## What each seat tends to catch

This comes from one bench and two runs, the hello-world fix and publishing
this skill, both on 2026-09-25. Treat it as a first reading, and update it as runs accumulate:

- **MiMo**: executes code to confirm a suspicion, and so finds behavioural
  bugs that reading alone misses (`main([])` silently reading the real argv).
  It is slower and wordier, with more non-blocking notes.
- **Nemotron 3 Ultra**: fast, terse, and accurate on spec and claim
  discipline. It can miss a bug that needs execution to see.
- **Claude**: synthesis, implementation, and probes.

## Run log

Log each run in the changed repo, as herdr-agent-fleet Step 8 says. Record
runs that change this skill in a log wherever you keep this skill's history.
