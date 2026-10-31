# Dry run: one issue in each lane

A written walk-through of `choose-lane` on three example issues, one per lane, in a repo made by Agentic Studio's
onboarding with the starter kit. The kit's example page is Notes (`/notes`, `src/lib/server/notes/`, texts in
`messages/en.json` and `messages/sv.json`). The fourth section runs the same flow in a repo without the kit.

Each section shows what the agent reads, which signal decides the lane, the Agent call it makes and the MCP calls in
order. Version 1.0.0 of the plugin.

## Small: issue 12, "The menu says Notes, the team calls them Meeting notes"

> The menu item and the page heading say "Notes". Change both to "Meeting notes" in the English texts. Nothing else
> changes.

1. `get_issue 12`: ready, no comments, no linked pull request. `start_work 12`: in progress.
2. **Lane.** The issue names the exact text and the places, and adds no behaviour. Nothing in the large column applies.
   Small.
3. Line to the developer: "Issue 12 goes as small: two texts, exact wording given."
4. Agent call: `subagent_type: agent-kit:quick-fix`, `model: haiku`, `effort: medium`. The brief holds the issue's
   text, "already started", and the pointer `messages/en.json`, keys `nav_notes` and `notes_title`.
5. `quick-fix` reads `AGENTS.md` (absent in the kit) and `docs/getting-started.md`, makes the worktree
   `../acme-app-12` on `fix/12-meeting-notes`, changes two values, searches for "Notes" and leaves the other hits with a
   reason, runs `bun run test`, `bun run lint`, `bun run check` and `bun run build`, opens the pull request
   `fix: the menu says Meeting notes (#12)`, then `link_pull_request 12 <url>` (in review) and `comment 12` with "Open
   the app; the menu and the page heading say Meeting notes."
6. Review round: the kit's `issue-reviewer` reads issue 12 and the diff. Nothing to fix.
7. `get_issue 12`: in review, one linked pull request, the test note is there. Stop.

**A hand-back in the same lane.** Had issue 12 said "and the heading shows how many notes there are", `quick-fix` would
see a new behaviour that needs a test, hand back with that reason and no worktree, and `choose-lane` would start
`feature-dev` on the normal lane with the reason in the brief.

## Normal: issue 14, "A person can delete a note"

> Each note has a Delete button. After deleting, the note is gone from the list and stays gone after a reload. An empty
> list shows "No notes yet."

1. `get_issue 14`, `start_work 14`.
2. **Lane.** New behaviour, in one part of the code (the notes module and its page), with criteria an orderer can test.
   It touches no sign-in or permission: the kit has no sign-in turned on and the issue asks for none. Normal.
3. Line: "Issue 14 goes as normal: new behaviour in the notes page, clear criteria."
4. Agent call: `subagent_type: agent-kit:feature-dev`, `model: sonnet`, `effort: medium`. Pointer:
   `src/lib/server/notes/index.ts` (`NoteStore`, `writeNote`) and `notes.test.ts`, the fake in `fake.ts`.
5. `feature-dev` makes `../acme-app-14` on `feat/14-delete-note` and follows `agent-kit:tdd`. Seams written down first:
   the notes module's public functions and the page's form action. Slice one: a test that a deleted note is not in
   `listNotes`, red, then `deleteNote` on the store and the fake, green. Slice two: the form action and the button. Then
   `agent-kit:verify-before-done` with the four kit checks, one commit `feat: a person can delete a note (#14)`, push,
   pull request, `link_pull_request 14 <url>`, `comment 14` with how to test it in the running app.
6. Review round: `issue-reviewer` reports that the empty list after the last delete has no test. One fix round by
   `feature-dev` on the same branch adds it.
7. `get_issue 14`: in review. Stop.

## Large: issue 17, "Each person sees only their own notes"

> Today everyone sees every note. Sign in with a link by email; after that a person sees and deletes only the notes they
> wrote.

1. `get_issue 17`. One comment from the orderer: "Sign-in by email is fine, no SSO for now." `start_work 17`.
2. **Lane.** It turns on sign-in and adds an ownership check: sign-in and permissions are both in the large column. It
   touches security. Large, effort high.
3. Line: "Issue 17 goes as large with high effort: it turns on sign-in and adds an ownership check."
4. Agent call: `subagent_type: agent-kit:feature-dev`, `model: opus`, `effort: high`. Pointer:
   `src/lib/server/auth/options.ts`, `docs/engineering/patterns.md#auth`, the notes module.
5. `feature-dev` writes the seams first (signing in, the notes module with an owner, the page's load and actions), works
   in slices, and runs the checks. It opens the pull request and links it.
6. Review round as above, with `REVIEW.md` read for the repo's own security rules.
7. `get_issue 17`: in review. Stop.

**If it goes red.** Three focused attempts at the same failure on the large lane: `feature-dev` commits what is green,
opens no pull request and reports with the output. `choose-lane` tells the developer; there is no lane above large.

## Without the starter kit: issue 31 in a repo that had code before

The repo has `.mcp.json` and the plugin enabled, but no `.claude/skills/` and no `docs/getting-started.md`. Issue 31:
"The export button also offers CSV."

1. No `work-an-issue` skill is there, so `choose-lane` runs the start itself: `list_my_work` shows 31 assigned and
   ready, `get_issue 31`, `start_work 31`.
2. **Lane.** New behaviour in one place with a clear criterion. Normal.
3. Agent call as for issue 14. `feature-dev` reads the repo's `AGENTS.md` for its commands (here `npm test`,
   `npm run lint`) and its code host (Azure DevOps), and opens the pull request with `az repos pr create`.
4. Review round: there is no `issue-reviewer`, so a general-purpose agent reads issue 31, the diff and `REVIEW.md`, read
   only.
5. `link_pull_request 31 <url>`, `comment 31`, then `get_issue 31`: in review. Stop.

## What this dry run does not show

It is a walk-through, not a recorded run. The agent's real choices on a real issue, and whether `effort` reaches the
agent in a given Claude Code version, are checked on the first issue a customer team builds with the plugin.
