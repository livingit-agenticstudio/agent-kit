---
name: choose-lane
description: Pick the lane for an Agentic Studio issue (small, normal or large) and start the matching implementation agent with its model and effort, then run one review round. Use when an issue is ready to build, when asked to work, take or build an issue, or when the work-an-issue skill reaches its Build step. Also use when an implementation agent hands an issue back.
---

# Choose a lane

You decide how much model and effort an issue needs, start the agent that builds it, and have its work read once by
someone who did not write it. The issue lives in the Agentic Studio portal and you reach it only through the
`agentic-studio` MCP tools. The code and the pull request live in this repo.

## 1. Get the issue

If the `work-an-issue` skill has already picked, read and started the issue, take what it read and go to step 2. This
skill replaces its Build step, and the agent you start also opens and links the pull request and writes the test note,
so `work-an-issue` has nothing left to do after you.

Otherwise run the start of the flow yourself:

1. **Pick.** Take the issue you were given. Without one, `list_my_work` shows what is assigned to you. Ready issues meant
   for an agent that nobody has taken show with `list_issues` (state `ready`, for whom `agent`). When several fit, ask
   the developer which.
2. **Read.** `get_issue`, and read every comment: the orderer's answers are there. When a requirement is unclear,
   `ask_orderer` with one focused question and what you would do if the answer is "no preference". Do not start an
   agent on what the answer decides.
3. **Start.** `start_work` assigns the issue to you and moves it to in progress. It works only on a ready issue. If it
   refuses, the issue is not ready: say so and stop. An issue already in progress and assigned to you goes on as it is.

## 2. Pick the lane

| Lane   | When                                                                                                                                                                                                                                       | Agent         | model / effort                                     |
| ------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------- | -------------------------------------------------- |
| Small  | The issue says exactly what changes and adds no behaviour: text in the interface, a translation, docs, config, a one-line fix                                                                                                             | `quick-fix`   | `haiku` / `medium`                                 |
| Normal | New or changed behaviour in one part of the code, with clear acceptance criteria                                                                                                                                                           | `feature-dev` | `sonnet` / `medium`                                |
| Large  | Breaks a public contract or protocol (adding to one is normal); touches sign-in, permissions, secrets or personal data; changes a rule the repo's `AGENTS.md` calls hard; deletes data or folders; spans more than one app; or leaves design open | `feature-dev` | `opus` / `medium`, `high` when it touches security |

- Between two lanes, take the higher one.
- The developer can name the lane ("build 42 as small"), and that wins.
- Read the acceptance criteria, not the title: a one-word title can hide a permission check.

Tell the developer the lane and the reason in one line, for example "Issue 42 goes as normal: new behaviour in the notes
page, clear criteria."

## 3. Start the agent

Start the agent with the Agent tool: `subagent_type` `agent-kit:quick-fix` or `agent-kit:feature-dev`, and both `model`
and `effort` from the table. If your Agent tool has no `effort` field, the agent's own default applies; still set
`model`.

The brief, in the prompt:

- The issue number, and that it is already started (so the agent does not call `start_work` again).
- The issue's text and comments as you read them, in full. Do not summarise away a requirement.
- The lane and why.
- Where to start, when you know it: the files or the folder, and an earlier commit that did something similar. Reading
  code is a large part of an agent's work, and a good pointer saves most of it.

## 4. When the agent hands back

- `quick-fix` says the issue is not small: start `feature-dev` on the normal lane with its reason in the brief.
- `feature-dev` stays red after three attempts, or reports that the change touches a large trigger: start it again one
  lane up rather than patching on the cheaper lane.
- On the large lane and still red: stop and tell the developer what failed, with the output.
- The agent asks a question the orderer must answer: `ask_orderer`, then stop until the answer is in the issue.

## 5. One review round

When the pull request is open, have it read once in a fresh context, by an agent that did not write it:

- The repo has an `issue-reviewer` agent (the starter kit puts it in `.claude/agents/`): start it with the issue number.
- Otherwise start a general-purpose agent, read only, with the issue number. It reads the issue with `get_issue`, the
  branch's diff against the default branch, and `REVIEW.md` when the repo has one, and reports what does not meet the
  issue or the repo's rules, with file and line.

Send the findings worth fixing to an agent of the same lane for one fix round on the same branch. Say which findings you
left and why.

## 6. Hand over

The agent has linked the pull request with `link_pull_request`, which moved the issue to in review, and has commented
what changed and how to test it. Check both with `get_issue`. Then stop: a person tests the work and decides in the
portal.

## What you never do

You never approve, send back, answer or close an issue. There is no tool for it and you do not look for a way: the
orderer or a developer does it in the portal. Whether and when to merge is the developer's decision under the repo's own
rules. Speak of an issue's state in the portal's words (ready, in progress, in review), as the MCP tools return them.
