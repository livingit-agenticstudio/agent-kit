# agent-kit

A Claude Code plugin for teams that work their issues in Agentic Studio. It decides how much model and effort an issue
needs, builds it test-first in its own git worktree, checks the work before it says done, and blocks destructive git
commands. This repo is both the plugin and its marketplace.

## Install

In the repo you build in, with Claude Code:

```
/plugin marketplace add livingit-agenticstudio/agent-kit
/plugin install agent-kit@agentic-studio
/reload-plugins
```

A repo made by Agentic Studio's onboarding already has it: its `.claude/settings.json` names this marketplace and
enables the plugin, so Claude Code offers to install it the first time the folder is trusted. The repo also needs the
portal's MCP server in `.mcp.json` (the portal shows it under "Connect your agent").

## What is in it

| Part                        | What it does                                                                                     |
| --------------------------- | ------------------------------------------------------------------------------------------------ |
| `choose-lane` skill         | Reads the issue, picks small, normal or large, starts the matching agent with its model and effort, and runs one review round |
| `feature-dev` agent         | Normal and large lanes: worktree, test-first, checks, pull request linked to the issue          |
| `quick-fix` agent           | Small lane: an exactly specified change with no new behaviour; hands back when it is bigger      |
| `tdd` skill                 | Vertical slices, tests at public seams, the anti-patterns                                        |
| `verify-before-done` skill  | No claim of done without fresh output from the repo's own checks                                 |
| Git guardrail hook          | Blocks force pushes, pushes to the default branch, `reset --hard`, `clean -f`, `branch -D`, discarding the whole tree, dropping stashes and skipping hooks |

The lanes:

| Lane   | When                                                                       | Agent         | model / effort                         |
| ------ | -------------------------------------------------------------------------- | ------------- | -------------------------------------- |
| Small  | Exactly specified, no new behaviour                                        | `quick-fix`   | haiku / medium                         |
| Normal | New or changed behaviour in one part, clear criteria                       | `feature-dev` | sonnet / medium                        |
| Large  | Contracts, sign-in, permissions, secrets, deletion, several apps, open design | `feature-dev` | opus / medium, high for security    |

Between two lanes it takes the higher. An agent that hands back reruns the issue one lane up.
[docs/dry-run.md](docs/dry-run.md) walks one issue through each lane, and one through a repo without the starter kit.

## With and without the starter kit

The starter kit's own skills (`work-an-issue`, `write-an-issue` and the `issue-reviewer` agent) belong to the team and
stay in the repo. When `work-an-issue` reaches its Build step, `choose-lane` takes over. In a repo without the kit,
`choose-lane` runs the whole flow with the same MCP tools: `list_my_work`, `get_issue`, `start_work`, `ask_orderer`,
`link_pull_request` and `comment`. The repo's `AGENTS.md` or `CLAUDE.md` gives the commands, the checks and the code host.

## What it will not do

- It never approves, sends back, answers or closes an issue. A person does that in the portal.
- It never merges. When to merge is the team's decision under the repo's own rules.
- It never force-pushes, pushes to the default branch or deletes a branch it did not create.
- It does not write issues, and reviews only inside `choose-lane`: the starter kit's `write-an-issue` and `issue-reviewer` do
  that, and the team owns them.
- It does not run without Claude Code, and it changes nothing in your repo when it updates.

## Updates

Claude Code reads the plugin from this marketplace, so a new version reaches every repo that enables it without a change
to that repo. Onboarding turns on automatic updates for the marketplace; elsewhere, `/plugin marketplace update
agentic-studio` fetches the latest. A release raises `version` in `.claude-plugin/plugin.json`, since Claude Code only
updates a plugin whose version changed.

## Develop

```sh
claude plugin validate .                 # the manifests, skills, agents and hooks
tests/block-destructive-git.test.sh      # the git guardrail, blocked and allowed commands
claude --plugin-dir .                    # try it in a session without installing
```

Every file is in English, in plain sentences. No file names a person, a team's internal script or an issue label: the
plugin speaks of an issue's state in the portal's words.
