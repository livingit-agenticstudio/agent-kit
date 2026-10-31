#!/bin/bash
# Runs the git guardrail hook on commands it must block and commands it must let through.
# Usage: tests/block-destructive-git.test.sh

hook="$(cd "$(dirname "$0")/.." && pwd)/scripts/block-destructive-git.sh"
failures=0

input_for() {
	# The command as Claude Code sends it to a PreToolUse hook, with quotes escaped for JSON.
	local escaped=${1//\\/\\\\}
	escaped=${escaped//\"/\\\"}
	printf '{"tool_name":"Bash","tool_input":{"command":"%s","description":"x"}}' "$escaped"
}

expect() {
	local want=$1 command=$2 got
	input_for "$command" | "$hook" 2>/dev/null
	case $? in
		0) got=allowed ;;
		2) got=blocked ;;
		*) got=error ;;
	esac
	if [ "$got" != "$want" ]; then
		echo "FAIL: expected $want, got $got: $command"
		failures=$((failures + 1))
	fi
}

expect blocked 'git push --force'
expect blocked 'git push --force-with-lease origin feat/42-invoice'
expect blocked 'git push -f origin feat/42-invoice'
expect blocked 'git push -uf origin feat/42-invoice'
expect blocked 'git push origin +feat/42-invoice'
expect blocked 'git push origin main'
expect blocked 'git push origin HEAD:main'
expect blocked 'git push origin master'
expect blocked 'git push --delete origin feat/42-invoice'
expect blocked 'git push origin :feat/42-invoice'
expect blocked 'git push --mirror'
expect blocked 'git push --no-verify -u origin feat/42-invoice'
expect blocked 'git commit --no-verify -m "Add invoice"'
expect blocked 'git reset --hard origin/main'
expect blocked 'git clean -fd'
expect blocked 'git clean -xdf'
expect blocked 'git clean --force'
expect blocked 'git branch -D feat/42-invoice'
expect blocked 'git branch --delete --force feat/42-invoice'
expect blocked 'git checkout .'
expect blocked 'git checkout -- .'
expect blocked 'git checkout -f main'
expect blocked 'git restore .'
expect blocked 'git stash clear'
expect blocked 'git stash drop'
expect blocked 'cd ../app && git reset --hard'
expect blocked 'git -C ../app push --force'
expect blocked 'bun run test && git push origin main'
expect blocked 'git log --oneline; git reset --hard'
expect blocked 'git status | cat || git clean -f'

expect allowed 'git push -u origin feat/42-invoice'
expect allowed 'git push origin feat/42-main-menu'
expect allowed 'git push --follow-tags -u origin feat/42-invoice'
expect allowed 'git commit -m "Remove the force flag from the form"'
expect allowed 'git reset --soft HEAD~1'
expect allowed 'git clean -n'
expect allowed 'git branch -d feat/42-invoice'
expect allowed 'git checkout -b feat/42-invoice origin/main'
expect allowed 'git restore src/lib/invoice.ts'
expect allowed 'git stash list'
expect allowed 'git status --short --branch'
expect allowed 'gh pr create --base main --title "feat: invoice (#42)" --body-file /tmp/body.md'
expect allowed 'bun run test'
expect allowed 'echo main'

if [ "$failures" -gt 0 ]; then
	echo "$failures failed"
	exit 1
fi
echo "all passed"
