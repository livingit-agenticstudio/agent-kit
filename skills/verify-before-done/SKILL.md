---
name: verify-before-done
description: Use before saying work is done, fixed or passing; before a commit, push or pull request; and before passing on a subagent's report that its work is done.
---

# Verify before done

A claim about the state of the work rests on **evidence**: the output of a command run after the last edit, read down to
the exit code and the failure count. A claim without evidence is a guess, and is said as one.

Adapted from obra/superpowers `verification-before-completion` (MIT).

## Steps

1. **Name each claim and its proof.** Take the command from the repo's own docs (`AGENTS.md`, `CLAUDE.md`,
   `docs/getting-started.md`, the runbook). Done when every claim you are about to make has a command next to it.
2. **Run what is not fresh.** A run after the last edit is fresh; reuse it. Run everything else again, in full. Done
   when each command has output from after the last edit.
3. **Read the output.** Exit code, counts, the last lines. A hook's output is evidence once you have read it; a commit
   made with the hooks skipped has none.
4. **Say it with the evidence:** "`bun run test`: 412 pass, 0 fail, on macOS." Say what failed or could not run just as
   plainly, with the reason. Where you would write *should* or *probably*, run the command instead.

## What proves what

| Claim               | Evidence                                                    | Not evidence                     |
| ------------------- | ----------------------------------------------------------- | -------------------------------- |
| Tests pass          | the full suite after the last edit, 0 fail                  | one file's run, an earlier run   |
| It builds           | the build's exit 0                                          | type check or lint passing       |
| Bug fixed           | the original symptom reproduced, now gone                   | the code changed                 |
| It works on an OS   | built and run on that OS                                    | the tests of a shared library    |
| A subagent finished | `git log` and `git diff` on its branch, and its checks' output | its report                    |
| The issue is done   | each acceptance criterion ticked against the diff           | green tests                      |

## Unverified

Name what this machine cannot check (a Windows build on a Mac, a manual test in the running app) as unverified, next to
the claim it limits. Write in the pull request's checks section what ran, on which OS, with what result, and what did
not run and why.
