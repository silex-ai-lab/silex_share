# silex_share

Claude Code skills shared by Silex AI.

## Skills

| Skill | What it does |
| --- | --- |
| [`herdr-agent-fleet`](skills/herdr-agent-fleet/SKILL.md) | Runs Claude, a DeepSeek-backed OpenCode agent and (when available) Codex as [Herdr](https://herdr.dev) panes working one task together. Two unanimous gates: no code before every seat returns `PLAN-APPROVED`, nothing pushed or deployed before every seat returns `IMPL-APPROVED`. |

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

## License

[MIT](LICENSE)
