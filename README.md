# agent-kit

A Claude Code plugin for teams that work their issues in Agentic Studio. It decides how much model and effort an issue
needs, builds it test-first in its own git worktree, checks the work before it says done, and blocks destructive git
commands. This repo is both the plugin and its marketplace.

## Install

From the repo you build in:

```
claude plugin marketplace add livingit-agenticstudio/agent-kit
claude plugin install agent-kit@agentic-studio
claude
```

While this repo is private, installing and updating need read access to it with your own git login.

A repo made by Agentic Studio's onboarding already names the marketplace and enables the plugin in
`.claude/settings.json`, so Claude Code offers to install it when you trust the folder. The repo also needs the portal's
MCP server in `.mcp.json` (the portal shows it under "Connect your agent").

## What is in it

- `choose-lane` skill: reads the issue, picks a lane, starts the matching agent, and runs one review round.
- `quick-fix`, `feature-dev` and `feature-dev-secure` agents: worktree, change, checks, a pull request linked to the
  issue. Each may use only file, shell and skill tools and the `agentic-studio` MCP tools it needs.
- `tdd` and `verify-before-done` skills.
- A git guardrail hook. It blocks force pushes, pushes to or from the default branch, deleting branches, refs, reflogs
  or stashes, `reset --hard`, `clean -f`, discarding the whole tree, and skipping the repo's hooks. It reads the command
  the way the shell does, so text that only mentions git passes. A command it cannot read is blocked.

| Lane            | Agent                | Model  | Effort |
| --------------- | -------------------- | ------ | ------ |
| Small           | `quick-fix`          | haiku  | medium |
| Normal          | `feature-dev`        | sonnet | medium |
| Large           | `feature-dev`        | opus   | medium |
| Large, security | `feature-dev-secure` | opus   | high   |

The model is set on the call, and the effort in each agent's file. Between two lanes it takes the higher one, and an
agent that hands back reruns the issue one lane up. [docs/dry-run.md](docs/dry-run.md) walks one issue through each
lane, and one through a repo without the starter kit.

## With and without the starter kit

The starter kit's own `work-an-issue`, `write-an-issue` and `issue-reviewer` belong to the team and stay in the repo.
When `work-an-issue` reaches its Build step, `choose-lane` takes over. Without the kit, `choose-lane` runs the whole flow
with the same MCP tools, and the repo's `AGENTS.md` or `CLAUDE.md` gives the commands, the checks and the code host.
Without an `issue-reviewer`, the review is a general-purpose agent told to only read: that is an instruction in its
prompt, not a limit on its tools.

## What it will not do

- Approve, send back, answer or close an issue. A person does that in the portal.
- Merge. When to merge is the team's decision under the repo's own rules.
- Change anything in your repo when it updates.
- Run without Claude Code.

## Trust

A plugin release runs on your machine: its hook runs before every shell command, and its agents run commands in your
repo. Only Livingit's maintainers with write access to this repo can publish a release. Releases are tagged
(`v1.0.1` and on) and raise `version` in `.claude-plugin/plugin.json`; Claude Code updates only when that changes.

You decide how updates arrive:

- **Turn auto-update off:** `/plugin`, Marketplaces, `agentic-studio`, turn off auto-update. Or set `"autoUpdate": false`
  on the marketplace in `.claude/settings.json`. Update by hand with `claude plugin marketplace update agentic-studio`.
- **Pin a version:** add `"ref": "v1.0.1"` to the marketplace's `source` in `.claude/settings.json`. You stay on that tag
  until you change it.

## Develop

```sh
claude plugin validate . --strict
tests/block-destructive-git.test.sh
tests/agents.test.sh
claude --plugin-dir .
```

Every file is in English, in plain sentences. No file names a person, a team's internal script or an issue label.
