# silex_share

Claude Code skills shared by Silex AI.

## Skills

| Skill | What it does |
| --- | --- |
| [`herdr-agent-fleet`](skills/herdr-agent-fleet/SKILL.md) | Runs Claude, a DeepSeek-backed OpenCode agent and (when available) Codex as [Herdr](https://herdr.dev) panes working one task together. Two unanimous gates: no code before every seat returns `PLAN-APPROVED`, nothing pushed or deployed before every seat returns `IMPL-APPROVED`. |
| [`herdr-fleet-free`](skills/herdr-fleet-free/SKILL.md) | Zero-cost variant of `herdr-agent-fleet`: Claude plans and implements, and two free open-weight models served through OpenCode Zen review the plan and the code. Both gates are unanimous across all three seats. Only for public or non-sensitive code — free endpoints may log prompts. |

## Install

Copy or symlink a skill folder into `~/.claude/skills/`:

```bash
git clone https://github.com/silex-ai-lab/silex_share.git
ln -s "$PWD/silex_share/skills/herdr-agent-fleet" ~/.claude/skills/herdr-agent-fleet
```

### Requirements for `herdr-agent-fleet`

- [Herdr](https://herdr.dev), with Claude Code started inside a Herdr pane
- [OpenCode](https://opencode.ai) on `PATH`
- `DEEPSEEK_API_KEY` exported in the shell Herdr panes start
- Optional: [Codex CLI](https://github.com/openai/codex) for the third seat (the skill checks whether it actually runs; a two-seat roster needs your explicit OK)

### Requirements for `herdr-fleet-free`

- [Herdr](https://herdr.dev), with Claude Code started inside a Herdr pane
- [OpenCode](https://opencode.ai) on `PATH` (no API key needed for the free Zen models)

## License

[MIT](LICENSE)
