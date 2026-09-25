# silex_share

Claude Code skills shared by Silex AI.

## Skills

| Skill | What it does |
| --- | --- |
| [`herdr-agent-fleet`](skills/herdr-agent-fleet/SKILL.md) | Runs Claude and a DeepSeek-backed OpenCode agent as [Herdr](https://herdr.dev) panes working one task together. DeepSeek reviews the plan before any code is written. |
| [`thesis-interrogation`](skills/thesis-interrogation/SKILL.md) | An eight-step questioning loop for stress-testing a market thesis, category definition, or startup direction: structure transfer, laddering up, reality checks against capital and competitors, taxonomy gaps, and causal direction. Written in Chinese. |

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
