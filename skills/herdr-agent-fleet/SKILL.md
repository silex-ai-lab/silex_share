---
name: herdr-agent-fleet
description: >-
  Orchestrate a coding fleet inside Herdr panes for one task: Claude plans and
  takes the judgment-heavy slice, DeepSeek (run through OpenCode) reviews the
  plan before any code is written and then does the bulk of the implementation
  in a parallel pane, and Codex — when it runs on this machine, which you check
  rather than assume — reviews the plan and the code as a third judge.
  Two gates are unanimous: no code is written until every seat returns
  PLAN-APPROVED, and nothing lands on a shared branch, is pushed or is deployed
  until every seat returns IMPL-APPROVED. Each run is recorded in the target project's log
  directory. Routine design questions go to the other seats; a genuine split
  goes to the user. Also covers installing Herdr plugins from the marketplace.
  Use when the user asks to run a multi-agent coding fleet via Herdr, wants
  agents split across panes, wants a plan or a diff reviewed by other models
  before work starts or ships, or wants a second opinion instead of stopping
  for review.
---

# Herdr multi-agent fleet: Claude + DeepSeek(OpenCode) + Codex, unanimous plan and code review

This skill runs Claude, a DeepSeek-backed OpenCode agent and (when it runs) a
Codex agent as Herdr panes working one task together, using Herdr's socket API
(`herdr agent ...` / `herdr pane ...`) for coordination instead of manual
copy-paste between terminals.

Roles — do not reassign without the user explicitly asking:
- **claude** (this agent, in the calling pane) — owns the plan, resolves
  splits between reviewers, and codes the slice needing full conversation
  context or judgment calls. Claude is also a judge: its own approval is an
  explicit vote, stated in the plan, not an assumption.
- **deepseek** (`--kind opencode -- -m deepseek/deepseek-chat`, or
  `deepseek/deepseek-reasoner` for review and harder tasks) — reviews the
  plan and the code, then takes the bulk of well-scoped implementation in a
  parallel pane.
- **codex** (`--kind codex`) — reviews the plan and the code. The most
  expensive seat; not used for mechanical implementation.

**The two gates are unanimous.** Planning (Step 4) and code review (Step 7)
pass only when **every seat on the roster** approves, each with a literal,
written verdict. Claude's verdict is written down too. Majority voting applies
only to routine design questions raised mid-work (Step 6).

**The roster is Claude + DeepSeek + Codex by default.** If a seat is
unavailable, or you want to replace one, the user must authorize the reduced or
replacement roster. Record it in the run log and require unanimity from that
roster. Without that authorization, a missing seat leaves the gate pending; it
never passes by default.

**What "commit" means under the gates.** Local checkpoint commits on a
private working branch are fine at any time. Nothing is merged or committed to
a shared branch (`main`, when the repo commits straight to `main`), pushed, or
deployed before Step 7 passes. The plan file itself is the exception: it may
be committed with its review record at any time.

## The Codex seat — check, don't assume

**Check whether Codex works before deciding the fleet has two seats.** It is
worth a third seat when it runs: it reads a plan differently from both Claude
and DeepSeek, and in practice it catches errors that neither of the other two
seats does.

```bash
codex --version                  # runs it; a `which` check proves nothing
```

If `codex --version` prints a version, you have three seats. Use them.

### Some managed machines block Codex — and that can change

Endpoint protection with a custom enterprise blocklist can quarantine the
Codex binary **on execution**: `npm i -g @openai/codex` succeeds, the binary
sits on disk untouched, and the first invocation deletes it — leaving a
`codex` on `PATH` that fails `ENOENT` from its npm wrapper. Reinstalling just
repeats the cycle. If you see that pattern, stop reinstalling and tell the
user.

The reverse happens too: a machine's policy changes, and a note saying
"Codex is blocked here" outlives the block. Treat this as the general
lesson: **an environment claim in a skill is evidence from a date, not a
standing fact.** Cheap to re-check, expensive to believe wrongly —
believing a stale "blocked" note costs a whole review seat.

### Shape with three seats

```bash
herdr agent start reviewer-codex --kind codex --pane <paneB>
```

- **claude** — owns the plan, takes the judgment-heavy slice, and casts the
  third vote.
- **coder-deepseek** — reviews the plan and the diff, then does bulk
  implementation.
- **reviewer-codex** — reviews the whole plan and the whole diff (see below
  for why it earns that), and takes narrow Step 6 questions. It is the
  most expensive seat; do not spend it on mechanical work.

Three voices make a majority possible, but **only Step 6 uses it**. The plan
gate and the code gate need all three. A 2-1 split there is not a pass; it
is another round (see Step 4, "Resolving a split between reviewers").

### Shape with two seats, if Codex really is unavailable

**Only with the user's say-so.** The gates default to three seats. Ask the
user to authorize a two-seat roster, or a replacement third seat, and record
the roster in the run log. Until they answer, the gates stay pending.

- **Plan review is DeepSeek's**, not a second Claude pass. The value is that a
  *different* model reads the plan; self-review keeps the ritual and loses the
  point.
- **There is no tiebreaker.** Agreement is agreement; disagreement goes to the
  user. Do not invent a third vote by asking one agent twice or weighting your
  own opinion double.
- Any other model reachable through OpenCode can fill a third seat
  (`herdr agent start <name> --kind opencode -- -m <provider>/<model>`),
  with the user's authorization, recorded in the run log like any roster change.

### What the Codex seat actually catches

Concrete examples of the standard to aim for, not decoration:

1. **Rejected a security design as insufficient.** A plan tested that no SQL
   string contained `'account'` or `'credential'`. Codex pointed out that this
   misses joins, `SELECT *`, views and accidental logging, and required instead
   a canary token in a fixture DB asserted absent from *all* output — returned
   values, JSON encoding, and error descriptions. Strictly better.
2. **Corrected a false premise.** Claude asserted that a machine without Xcode
   has no way to run SwiftPM tests. Codex found
   `/Library/Developer/CommandLineTools/usr/libexec/swift/pm/swiftpm-testing-helper`
   and separately vetoed reaching for `Testing.__swiftPMEntryPoint` as a
   double-underscore integration symbol rather than stable API.

Note the second one only half-held: the helper it found exited 0 with no output,
so the implementation went the other way anyway, with the stability risk
documented in-code. **A second opinion is evidence, not an order** — when you
try its recommendation and it demonstrably fails, that is new information the
reviewer did not have. Say so plainly and proceed; don't silently discard it,
and don't follow it off a cliff.

### What each seat tends to catch (three seats, unanimous gates)

The seats are **not interchangeable**. Across plan reviews and multi-round
code reviews of UI-heavy work, each found things the others missed:

| Seat | Typical catch | Examples |
|---|---|---|
| **Codex** | **State and flow bugs across a UI**, and **claims that outrun the evidence** | Illustrative fixtures presented as real execution evidence; an approval that didn't persist on reopen; a re-run mixing two candidates' metrics; success text left visible under a failure state; a closed item inheriting the previous item's hidden state; a label that stayed attached to the wrong candidate after an edit |
| **DeepSeek** | **Grounding in the actual code and data**, and fit with the existing design system | A planned demo step the engine couldn't actually perform, so it could only be faked; a displayed grade with no source in the data; the same control labelled with two different strings; new panels must reuse the site's own fonts and tokens; a serving layer missing from an adapter plan |
| **Claude** | **Synthesis**: resolving splits, keeping the scope simple, implementing, and writing probes | Found the placement both reviewers could accept; turned every acceptance criterion into a headless browser probe |

DeepSeek reported honestly that it **cannot read images** ("this model has no
image input"). Give it the diff and probe results as text; screenshots are for
Codex and for you.

## Prerequisite: the official Herdr skill

This skill is a **workflow** built on Herdr's CLI; it is not a CLI reference
and deliberately doesn't restate one. Herdr ships its own skill covering
pane/agent/workspace semantics, lifecycle states, ID handling, read sources
and error codes — load it before running anything here.

If a `herdr` skill is already in context, use it. Otherwise:

```bash
herdr --skill                 # prints the skill for the installed binary
```

To keep it available permanently:

```bash
mkdir -p ~/.claude/skills/herdr && herdr --skill > ~/.claude/skills/herdr/SKILL.md
```

**Re-export it after `herdr update`.** The skill is generated by the
installed binary and describes that version's syntax — a stale copy is
worse than none, because it reads authoritative. The binary is always the
authority: when the two disagree, the binary wins and this file is wrong.

Things below assume you have it, in particular: `idle` vs `done` (a
`--no-focus` pane settles to `done`, not `idle`), `agent_blocked` and
`agent_prompt_stalled`, and the alternate-screen limit on `agent read`.

## Precondition: must already be running inside a Herdr pane

```bash
test "${HERDR_ENV:-}" = 1
```

If this fails, stop. Tell the user to start a Herdr session and run Claude
Code inside it (`herdr`, then start `claude` in the pane it opens) — per
Herdr's own rules, never inspect or control a Herdr session from outside it.

## Preflight

```bash
opencode --version || echo "opencode: BROKEN"
codex --version   || echo "codex: unavailable - fall back to two seats"
zsh -ic 'env | grep -q "^DEEPSEEK_API_KEY=" && echo "deepseek key: set" || echo "deepseek key: MISSING"'
```

**Run each binary; do not use `which`.** A wrapper on `PATH` and a working
tool are different claims and they fail independently. This cuts both ways,
and both directions happen in practice:

- `which codex` returns a path while every invocation dies `ENOENT`, because
  endpoint protection deletes the binary on execution.
- A skill or note *says* codex is blocked while `codex --version` works fine.
  Believing the note costs a review seat.

Run it. It takes one second and settles the question either way.

If `opencode` won't run, stop and say so — DeepSeek carries the bulk of the
implementation and there is no redundancy for it.

`DEEPSEEK_API_KEY` must be visible to the shells Herdr panes start. Setting
it in your shell rc file (e.g. `~/.zshrc`) works — Herdr panes run
interactive shells. To confirm OpenCode sees it, `opencode providers list`
should show DeepSeek under "Environment", and
`opencode run -m deepseek/deepseek-chat "say hi"` should return a real
completion.

Mind which shells read which file: `~/.zshrc` is only sourced by
**interactive** zsh, so `zsh -lc` will *not* see the key and `zsh -ic` will.
Any non-interactive check you write must account for that, or it will
report a false "missing key". If the key really is absent, stop and ask the
user to set it themselves — never handle the key's value, and never fall
back to a different model for the deepseek seat without saying so.

## Optional: Herdr plugins

Plugins add workflow commands and plugin-owned panes. The fleet works
without any, so treat this as opt-in — **install one only when a specific
need in the task calls for it, and only after the user agrees.**

```bash
herdr plugin list                                   # what's already installed
herdr plugin install <owner/repo>                   # e.g. herdr plugin install someone/herdr-foo
herdr plugin install <owner/repo/subdir> --ref v1.2 # monorepo subdir, pinned ref
herdr plugin enable <name> / disable <name>
herdr plugin action                                 # list or invoke a plugin's actions
herdr plugin log                                    # inspect a plugin's command logs when it misbehaves
```

**The install argument is a GitHub `owner/repo`, not a marketplace display
name.** The marketplace page shows `herdr plugin install [plugin-name]`,
but the CLI signature is `<OWNER/REPO[/SUBDIR]>` — passing a bare display
name fails. Get the repo path from the plugin's marketplace entry.

Browse at **https://herdr.dev/plugins/** — the index is built automatically
from public GitHub repos carrying the `herdr-plugin` topic.

**That automatic indexing is the whole security story: there is no review
queue.** Herdr's own marketplace says listings aren't reviewed and to
install at your own discretion. A plugin is third-party code that runs in
the user's session, so:

- Never install one the user didn't ask for or agree to.
- Name the exact `owner/repo` you intend to install and let the user confirm
  it, rather than installing something whose name merely sounds right.
- Prefer `--ref <tag-or-sha>` over floating the default branch.
- If a plugin is only a convenience for something you can already do with
  `herdr agent` / `herdr pane`, skip it — a dependency is not worth a
  shortcut.

On a machine whose endpoint protection quarantines unrecognised binaries
(see the Codex section), a plugin that ships its own binary can be removed
the same way. If a plugin stops working right after installing, check your
endpoint protection's quarantine or threat list before debugging the plugin.

## Step 1 — Claude drafts the plan

Write a short numbered task list. Tag each task with an owner (`claude` or
`deepseek`) and a one-line acceptance check.

- **you** — tasks needing full conversation context or ambiguous judgment.
- **deepseek** — the bulk of mechanical, well-scoped implementation.

Split the slices so they never touch the same files — you work in parallel
and cannot see each other's edits.

**Write the file ownership out explicitly**, as a literal path list per owner,
and tell each agent not to touch anything outside its list. This works better
than it sounds: in one run DeepSeek needed a `Package.swift` change to make
the test target build, and because that file was listed as Claude's it
*reported the required change instead of making it* — "I did not touch
Package.swift (not my file). Apply that change and swift test will be green."
That is exactly the behaviour you want, and it only happens if ownership was
stated.

**Plan the shared foundation as the first task, and build it alone, first
thing in Step 5, before dispatching** (never before the planning gate passes).
The types the other agent compiles against (models, protocols, package
manifest) must exist and build green before it starts, or it will invent its
own and you will spend the reconcile merging two incompatible designs. Make a
local checkpoint commit of that foundation, *then* prompt.

**Ownership is a concurrency guard, not a property right.** Once the other
agent reports `done`, the lock is gone — fix small gaps in its files yourself
rather than paying a multi-minute round-trip. (A missing
`requestAuthorizationIfNeeded` on a notifier is a two-line fix, not a task.)

This is a **draft**. It does not survive contact with Step 4 unchanged very
often, and it isn't supposed to — don't over-polish it before review.

## Step 2 — Lay out the pane

```bash
herdr pane layout --pane "$HERDR_PANE_ID"
herdr agent list                      # which panes already have agents
```

**Check for idle panes before splitting.** A workspace often already has
panes from earlier work sitting at a shell prompt. `herdr agent list` shows
only panes with a registered agent, so a pane absent from that list and
showing a prompt is free. Reuse it rather than subdividing the screen
further — on a 3-pane layout, two more splits make every pane unreadable.

Point a reused pane at the right directory first:

```bash
herdr pane send-text <paneId> "cd /path/to/repo && clear"
herdr pane send-keys <paneId> enter
```

Only split when there is genuinely nothing free:

```bash
herdr pane split --current --direction right --cwd "$PWD" --no-focus
```

Read the new pane ID from `.result.pane.pane_id` in the JSON response —
never guess or reuse an ID from an earlier example. Split a wide pane
right, a tall one down.

## Step 3 — Start the coder agent

```bash
herdr agent start coder-deepseek --kind opencode --pane <paneA> -- -m deepseek/deepseek-reasoner
```

Use `deepseek-reasoner` when the same seat will review the plan in Step 4;
`deepseek-chat` is fine when the work is purely mechanical.

`agent start` blocks (up to its timeout) until the agent is ready for
input. `agent_not_ready` means it's blocked at startup, not failed — check
with `herdr agent get <name>` before retrying.

**Do not send the first prompt immediately after `agent start`.** Observed
with a codex-kind agent, and the failure mode is not
kind-specific: `agent start` reported `idle`/`interactive_ready` while the
TUI was still painting its splash and update banner, the first `agent
prompt` text was swallowed with no trace, and `--wait` still returned
success (`agent_prompted`) because unrelated startup redraws satisfied its
lifecycle-change check. Nothing ran, and nothing said so.

So confirm the prompt actually landed rather than trusting the return value:

```bash
herdr agent wait coder-deepseek --timeout 30000
herdr agent prompt coder-deepseek "<first message>" --wait --timeout 600000
herdr agent read coder-deepseek --source recent-unwrapped --lines 40
```

**Wait bare — do not write `--until idle` here.** The pane is created with
`--no-focus`, and an unfocused pane finishing background work settles to
`done`, not `idle`; CLI reads don't mark it seen either. `--until idle`
would sit there until the timeout while the agent is in fact ready. Bare
`agent wait` already defaults to the settled set (`idle`/`done`/`blocked`).

The read must show your prompt text echoed in the agent's composer or
transcript. If it doesn't, the input was swallowed — re-send it once, then
verify again before assuming the agent is working.

Two error codes to read rather than retry blindly: `agent_prompt_stalled`
means no lifecycle change was observed within five seconds of a prompt sent
from a non-working state; `agent_blocked` means the agent was already
sitting at an approval or question dialog and **no input was sent at all**.
Neither is fixed by re-sending — inspect with `agent get` / `agent read`
first, and route a blocked agent through Step 6.

A third: **`agent_not_idle`** comes back from `agent read` while OpenCode is
working — its alternate-screen history can only be captured while idle. It is
not an error in your command. Either wait, or read with `--source visible` to
see the current frame.

### Codex's startup dialogs

`herdr agent start reviewer-codex --kind codex --pane <pane>` returned
`agent_not_ready`. Codex was sitting at two dialogs, in order:

1. **Update available** (`1. Update now / 2. Skip / 3. Skip until next version`).
   Choose **Skip** (`send-keys down`, check the highlight with `--format ansi`,
   then `enter`). Do not choose "Update now": it runs `npm install -g`, which
   is an install the user did not ask for.
2. **"Do you trust the contents of this directory?"** This appears on the first
   prompt, as `agent_blocked`. Answer it only for the user's own repos. If
   `herdr agent send-keys <name> enter` does not clear it,
   `herdr pane send-keys <pane> enter` does.

The first prompt after that can land in the composer as
`[Pasted Content N chars]` without being submitted. Read the visible frame,
and send one `enter` if you see it waiting. Later prompts submitted normally.

### When `agent send-keys` doesn't dismiss a dialog

Several times, `herdr agent send-keys coder-deepseek enter`
returned `ok` while the OpenCode permission dialog stayed up and the agent
stayed `blocked`. **`herdr pane send-keys <paneId> enter` worked every time.**
Check `agent get` after answering a dialog; don't assume it cleared.

### OpenCode's permission dialogs, which you will hit

OpenCode stops for approval whenever it wants a path outside its cwd, and
during a plan review it will want one — the requirement docs usually live in
another repo. Two things make this fiddly:

- **It is a two-stage dialog.** `Allow once / Allow always / Reject`, and then
  a second `Confirm / Cancel` screen confirming the choice. Answering the
  first and walking away leaves the agent still blocked.
- **A plain read cannot tell you which option is selected.** The highlight is
  colour. Use `--format ansi` and look for the inverted background before you
  press Enter — confirming the wrong option here rejects work or grants more
  access than the user agreed to:

```bash
herdr agent send-keys <name> right
herdr agent read <name> --source visible --lines 8 --format ansi | cat -v
herdr agent send-keys <name> enter
```

Its requests **widen as it explores** — one subdirectory, then the repo, then
the parent of every project on the machine. Granting the first does not commit
you to the last. Read each path and reject the ones that overreach; usually it
is faster to answer the question it was chasing than to widen access.

### Fixtures beat access

When an agent asks for a path outside its cwd, the reflex is to decide
allow-vs-reject. There is usually a third option that is better than both:
**extract what it needs yourself and hand it over as a fixture.**

Worked example. DeepSeek was writing parsers for Claude Code,
Codex and OpenCode session files, so it wanted `~/.claude`, `~/.codex` and
`~/.local/share/opencode`. Granting that would have given a third-party model
the user's entire private transcript history plus a SQLite DB containing live
`access_token` and `refresh_token` rows. Instead:

1. Reject the request.
2. Read the real files yourself — you already have that access.
3. Write small sanitized fixtures into the repo (fake paths, fake ids,
   realistic structure) and commit them.
4. Re-prompt: "do NOT read ~/.claude etc., use
   `Tests/.../Fixtures/claude_session.jsonl`", and paste the exact record
   shapes you observed.

This is strictly better on three axes, not a security-vs-speed tradeoff:

- **Privacy.** The user's real work never reaches the other model.
- **Correctness.** You paste the *exact* schema you read, so the agent stops
  guessing field names. Include the traps: the Codex rollout format has a
  `thread_token_usage` that is **cumulative**, and an agent summing it across
  records multi-counts badly. Saying so up front cost one sentence and bought
  a passing test.
- **Tests.** Fixtures are checked in, so the suite is reproducible on a
  machine with none of those agents installed.

It also removes a whole class of permission round-trips: the agent stops
asking, because it no longer needs anything outside the repo.

**Its first message is the plan review in Step 4, not a coding task.**

## Step 4 — The planning gate: every seat approves the plan

No implementation work starts until **every seat** has approved the plan: the
literal `PLAN-APPROVED` from DeepSeek, the same from Codex, and your own
approval written into the plan.

**Write the plan to a file in the target repo** (e.g.
`logs/YYYY-MM-DD_<TOPIC>_PLAN.md` or `PLAN.md`), not only into a prompt. The
reviewers read it with their own tools and can check it against the code,
and the file becomes the run's record (Step 8).

**Send the byte-identical prompt to both reviewers at once**, then wait for
both. Sequential review wastes time, and a reworded second prompt is a
different question.

```bash
P="Review the plan at <repo>/<plan file> before any code is written. Read
whatever you need first (read-only; edit nothing): <context files>. Judge:
<the 3-4 things that matter for this task>. Reply in exactly one of two forms:
PLAN-APPROVED  or  PLAN-REJECTED followed by numbered blocking objections,
each naming the section/task and what to change. Only blocking objections:
things that make the plan wrong, unsafe, misleading, or unbuildable. Nits go
under NON-BLOCKING SUGGESTIONS."
herdr agent prompt reviewer-codex "$P"
herdr agent prompt coder-deepseek "$P Write your complete reply verbatim to <scratch dir>/deepseek-r1.md."
herdr agent wait coder-deepseek --timeout 590000; herdr agent wait reviewer-codex --timeout 590000
```

For design-heavy work, ask for structured advice before the verdict
("give advice under AESTHETICS / STRUCTURE / DATA PRESENTATION, then the
verdict"). The advice is where most of the value is; the verdict is the gate.

### Reading the verdicts

- **Read each verdict verbatim.** Never infer approval from `idle`/`done`,
  from a `--wait` success, or from a partial read. The literal token must be
  in something you actually read. An agent going quiet is not approval.
- **Codex:** read `recent-unwrapped` and cut from your own prompt text, so an
  older verdict in the scrollback can't be mistaken for the new one:
  `herdr agent read reviewer-codex --source recent-unwrapped --lines 120 | sed -n '/<first words of this round's prompt>/,$p' | sed -n '/PLAN-/,$p'`.
  Don't filter out indented lines: Codex's numbered objections are indented,
  and a `grep -v` on leading spaces silently drops their text.
- **DeepSeek (OpenCode):** it renders on the alternate screen, so long replies
  never reach Herdr's scrollback and a read comes back cut off. In practice
  this happens on nearly *every* review, so **ask for the file up front, in the same
  prompt**, rather than after a failed read. Put the file **outside the
  target repo** (your scratch dir). Given a repo path, it will create
  something like `logs/.review/` inside the repo you're changing, which then
  has to be cleaned out before committing. Writing outside its cwd triggers the permission
  dialog; "Allow once" is right for a scratch dir that holds only review
  material.

### Revising: objections become a table in the plan

1. For every blocking objection from any seat, change the plan, and add a
   row to a **"Round-N objections → changes"** table in the plan file:
   *objection (who) | change*. For an objection you disagree with, write the
   reason in that row. Never drop one silently.
2. Fold in non-blocking suggestions that are cheap and clearly right. List
   them in the same table, so the next round can see what moved.
3. **Send the next round to both reviewers, including one that already
   approved.** The revision may have broken something it approved.
4. After everyone approves, **a confirmation round is still needed if you
   then change the plan** (for example by folding in their non-blocking
   notes). Approval covers the text they read, not the text you wrote after.

### Resolving a split between reviewers

When reviewers want mutually exclusive things (e.g. Codex "keep this check
in stage A", DeepSeek "cut it, or move it to stage B"), **do not vote**. The
gate is unanimous. Instead:

1. Look for the version that answers both objections — typically a reframing
   that removes the reason one reviewer objected while keeping what the other
   needed (e.g. deriving the check from real data and labelling it
   illustrative, instead of presenting a fabricated scenario).
2. Write the split, your pick and your reason explicitly in the plan's
   objections table ("the one split: … my pick: … because …").
3. Send it back to both for judgment.

### When to stop and ask the user

Iterate as long as the rounds are **converging**: objections get narrower
and more concrete each time. Go to the user when:

- the **same** blocking objection survives two revisions;
- two seats still require mutually exclusive things after you've written a
  resolution and they have both judged it; or
- an objection is really a product or business decision (scope, audience,
  what to claim) rather than a correctness one.

Present each position in a sentence or two and let the user pick. Four or
more converging plan rounds are normal; "as many rounds as it takes until all
three agree" is the default here.

**Tell the user what review changed** before work starts, in a few
sentences. A plan that came out of review different is exactly what they
would have learned from reviewing it themselves.

Do not send an implementation task while a verdict is outstanding. A queued
second prompt makes it ambiguous which message a later reply is answering.

## Step 5 — Hand out work, don't poll

Only after every seat has approved the plan.

**First, record the review base:** `BASE=$(git rev-parse HEAD)` in each repo you will change, and write it into the plan file. Every Step 7 review diff is taken against it.

**When the whole change lives in one file** (a single-file web page, one big
config), don't split it across parallel agents. Two writers on one file
collide. One owner (usually you, because the work is judgment-heavy) edits
sequentially, and the other two seats become code reviewers in Step 7. State
this in the plan so the reviewers approve it as part of the plan.

Otherwise:

```bash
herdr agent prompt coder-deepseek "<task text, incl. acceptance check>" --wait --timeout 600000
```

Send the prompt, then do your own slice of the plan directly while it
works. **Do not `git add -A` during this window** — the other agent is
writing files continuously, and a sweeping commit will capture its
half-finished state — harmless on a private repo, but it puts a meaningless
snapshot in the history. Stage only your own paths, or
wait for `done`. Come back afterward and run bare `herdr agent wait coder-deepseek`
if it hasn't settled — never sit in a tight polling loop, and don't spell
out `--until idle --until done --until blocked`: that just restates the
default and, as in Step 3, an unfocused pane reaches `done` rather than
`idle`.

Be generous with timeouts: a trivial one-file task took over a minute of
real `working` time in testing. A `timeout` error back from `agent prompt
--wait` is **not** a failure — the agent is usually still working. Re-check
with `herdr agent get` and keep waiting via `herdr agent wait` instead of
re-sending the prompt, which would queue a duplicate task.

## Step 6 — Second opinion in place of human review

When the agent reports `blocked`, or your own work hits a decision point
that would normally need a human's sign-off (more than one reasonable
approach, an ambiguous design choice) — do not immediately interrupt the
user. Instead:

1. Write the decision as one self-contained question with the candidate
   options spelled out (e.g. "Approach A: X. Approach B: Y. Pick one and
   say why in one sentence.").
2. Reason about it yourself and record your own pick, then put the
   byte-identical question to deepseek:
   `herdr agent prompt coder-deepseek "<same question>" --wait --timeout 300000`
   A reworded second prompt is a different question and the comparison
   stops meaning anything.
3. Read the answer verbatim with `herdr agent read coder-deepseek --source
   recent-unwrapped --lines 120` — never assume or fabricate it. Use the
   file-output approach from Step 4 ("Reading the verdicts") for DeepSeek.
4. **If you agree**, apply that and tell the user in one or two sentences
   what was decided and why — this replaces the review gate, it doesn't
   hide the decision from them.
5. **If you disagree:**
   - *With three seats*, put the same question to the third and take the
     majority. Report the split and which way it went.
   - *With two seats*, ask the user. Two voices are not a majority. Do not
     break the tie by asking one agent twice, by weighting your own view
     double, or by picking the one you started with — present both positions
     and let the user decide.
   - *Either way*, if you tried the reviewer's recommendation and it
     demonstrably failed, that is new evidence it did not have, not a
     disagreement. Say so plainly, proceed with what works, and record why.
6. Ask the user directly regardless of agreement when the decision is
   genuinely irreversible or high-blast-radius (force-push, deleting data,
   spending money, touching shared/production systems). A second opinion
   substitutes for routine design-approach reviews, not for actions that
   need the user's actual authorization.

## Step 7 — The code-review gate: every seat approves the diff

Nothing is committed to a shared branch, pushed, or deployed until every seat
returns `IMPL-APPROVED` on the **current** diff. This gate is where most real
bugs turn up: the plan can be right and the implementation still carry
several defects (mostly in state and flow, sometimes a claim-discipline issue)
that only a reviewer reading the diff against the plan catches.

**1. Turn the acceptance criteria into probes before asking for review.**
For UI work, each criterion becomes a headless check that prints its result
into the page title, so a reviewer (and you) can read a verdict instead of a
screenshot:

```bash
# serve the working copy, inject one scripted scenario per page, read <title>
python3 -m http.server 8765 &   # from a scratch copy of the site
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new \
  --disable-gpu --virtual-time-budget=9000 --dump-dom http://localhost:8765/v-probe.html \
  | grep -o "<title>[^<]*</title>"
```

Examples that earn their keep: "threshold at minimum → Approve disabled",
"approve, reopen → same selection, control locked", "every page and every
nav item → no JS error". **Rebuild probe pages from the current file after
every fix.** Probes generated from an older copy pass while testing stale
code.

For a "must not change" area, test it both ways. A byte comparison of its
markup is necessary but not sufficient, so also compare rendered
screenshots, **and render the untouched original twice** as a control. A D3
layout differed between two renders of the *same* original, so a diff that
also appears in the control is noise, not a regression.

**2. Build the review diff against a fixed base, then send the same prompt
to both reviewers**, with the diff saved to a file, the screenshots, and the
probe results as text.

A plain `git diff` shows only unstaged changes to tracked files. It misses
local checkpoint commits, staged changes and new files, so a gate could
approve an incomplete diff while the rest ships unreviewed. Record the base
**before implementation starts** (first thing in Step 5), and always diff the
working tree against it, with new files marked intent-to-add:

```bash
BASE=$(git rev-parse HEAD)            # record at the start of Step 5; write it in the plan file
# ... implementation, including any local checkpoint commits ...
git add -N <each new file you intend to ship>
git diff "$BASE" > <scratch>/review.diff        # covers commits, staged, unstaged, intent-to-add files
git status --short                               # nothing untracked that should ship may be missing
git hash-object <scratch>/review.diff            # the revision id every verdict refers to
P="Implementation review (plan <version>, which you approved). Diff: <scratch>/review.diff
(git diff <BASE> in <repo>; revision <hash-object>). Screenshots: <paths>. Probes already passing: <list>.
Check the implementation against the plan and against claim discipline.
Reply in exactly one of two forms: IMPL-APPROVED  or  IMPL-REJECTED with
numbered blocking defects (file:line + what to change). Nits under NON-BLOCKING."
```

**3. Fix, re-probe, and resend the full current diff to both reviewers**,
including one that already approved an earlier version. It is common for
DeepSeek to approve round 1 while Codex rejects it; the fixes for Codex then
change code DeepSeek had approved, so both must judge again. Several code
review rounds, each finding something real and narrower than the last, are
normal.
Convergence is the signal to keep going. The escalation rules from Step 4
apply unchanged.

**4. Your own vote, written down.** Re-read the defects list against the diff.
If you think a reported defect is wrong, say why in the next round's prompt
rather than skipping it. When you approve, record a literal
`CLAUDE: IMPL-APPROVED` against the **same diff revision** the others
reviewed: the `git hash-object` of the full `git diff $BASE`, with the base commit recorded. Do the same at the plan
gate with `CLAUDE: PLAN-APPROVED` against the plan version. All the roster's
verdicts for the final revision go into the run log (Step 8) **before** you
commit to a shared branch or publish.

## Step 8 — Record the run in the project's log directory

Every run leaves a written record **in the GitHub repo it changed**, committed
together with the change:

- **The plan file** (`logs/YYYY-MM-DD_<TOPIC>_PLAN.md`, or the repo's own
  convention), containing the final plan, the **round-by-round "objections →
  changes" tables** (Step 4), the **roster**, and a closing **Outcome**
  section: how many plan rounds and code-review rounds, what each seat caught,
  and **every seat's literal final verdict, Claude's included**, against the
  plan version and diff revision it covers.
- **A changelog entry** in the repo's log index (e.g. `logs/README.md`): what
  changed, which areas were deliberately left untouched and how that was
  verified, and a link to the plan file.
- **Review transcripts**, if the user wants them, go in a `review/`
  directory. Check them before committing: a transcript can quote private
  files the reviewer read.

If the repo has no log directory, create `logs/` with a `README.md` index,
and say so in the commit message. Match the repo's language and naming
conventions (e.g. date-prefixed files and a newest-first changelog, if that
is what the repo already does).

Commit and push **only after Step 7 is unanimous**. If pushing deploys
something public (e.g. a site that auto-deploys from `main`), you need the user's go-ahead for that deployment as well as the three
approvals. A request like "once all three agree, update the site" is that
go-ahead. Then confirm the live result, e.g. by fetching the page and
checking that the new code is there.

## Step 9 — Wrap up

Once deepseek settles to `idle`/`done`, review its diff yourself, reconcile
with your own slice, and report the combined result to the user in a few
sentences: what shipped, what each review round changed, and where the log
is. Leave the panes attached rather than closing them. Tell the user the
agent names (`coder-deepseek`, `reviewer-codex`) so they can inspect or take
over with `herdr agent attach <name>`.

## Safety rules

- Never `herdr server stop`, or close a pane/tab/workspace you didn't
  create, unless the user explicitly asks.
- Never claim the plan was approved without the literal `PLAN-APPROVED`
  token from **every** reviewer, each in a transcript or file you actually
  read. Going `idle` is not agreement.
- **Never commit to a shared branch, push or deploy without `IMPL-APPROVED`
  from every seat on the roster, your own written verdict included, on the
  current diff revision.** An approval of an earlier diff does not cover later
  fixes.
- Never shrink or swap the roster without the user's authorization. A
  missing seat means the gate is pending, not passed.
- **The planning and code-review gates are unanimous. Never resolve a split
  there by vote.** Write a resolution into the plan and have every seat
  judge it again, or take it to the user.
- Never let a reviewer write review files into the target repo. Point its
  output at your scratch dir, and check `git status` for strays before
  committing.
- Never report the other agent's position without having actually read it.
- A `blocked` state means an agent is waiting on a decision — always run it
  through Step 6; never dismiss or auto-answer it.
- With only two seats there is no majority for Step 6 questions. When you
  and deepseek disagree, the user decides. Never manufacture a tiebreak.
- Every run is logged in the changed repo (Step 8). A change without its
  plan file and changelog entry is not finished.
- Never install a Herdr plugin the user didn't agree to. The marketplace is
  unreviewed by design.
- **Never hand a subagent access to the user's real private data when a
  sanitized fixture would do.** See "Fixtures beat access" above.
- **Never `git add -A` while a parallel agent is still writing.** You will
  commit its half-finished work. Wait for `done`.
- Re-check environment claims in this file before acting on them; they are
  dated evidence, not standing facts.
