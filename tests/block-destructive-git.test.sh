#!/bin/bash
# Runs the git guardrail hook on commands it must block and commands it must let through.
# Usage: tests/block-destructive-git.test.sh

hook="$(cd "$(dirname "$0")/.." && pwd)/scripts/block-destructive-git.sh"
failures=0

# Two throwaway repos: one on a feature branch whose origin/HEAD is `release`, one on `main`.
scratch=$(mktemp -d)
git_quiet() { git -c user.name=t -c user.email=t@example.com "$@" >/dev/null 2>&1; }
feature="$scratch/feature"
git_quiet init -b feat/42-invoice "$feature"
git_quiet -C "$feature" commit --allow-empty -m first
git_quiet -C "$feature" update-ref refs/remotes/origin/release HEAD
git_quiet -C "$feature" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/release
on_main="$scratch/on-main"
git_quiet init -b main "$on_main"
git_quiet -C "$on_main" commit --allow-empty -m first

json_string() {
	local s=${1//\\/\\\\}
	s=${s//\"/\\\"}
	s=${s//$'\n'/\\n}
	s=${s//$'\t'/\\t}
	printf '"%s"' "$s"
}

run() {
	# $1 = raw stdin for the hook. Prints allowed, blocked or error.
	printf '%s' "$1" | "$hook" 2>/dev/null
	case $? in
	0) echo allowed ;;
	2) echo blocked ;;
	*) echo error ;;
	esac
}

check() {
	local want=$1 got=$2 what=$3
	if [ "$got" != "$want" ]; then
		printf 'FAIL: expected %s, got %s: %s\n' "$want" "$got" "$what"
		failures=$((failures + 1))
	fi
}

# expect <allowed|blocked> <command> [cwd]
expect() {
	local cwd command payload got
	cwd=$(json_string "${3:-$feature}")
	command=$(json_string "$2")
	payload='{"tool_name":"Bash","cwd":'$cwd',"tool_input":{"command":'$command',"description":"x"}}'
	got=$(run "$payload")
	check "$1" "$got" "$2"
}

# Force, delete and mirror pushes.
expect blocked 'git push --force'
expect blocked 'git push --force-with-lease origin feat/42-invoice'
expect blocked 'git push -f origin feat/42-invoice'
expect blocked 'git push -uf origin feat/42-invoice'
expect blocked 'git push -ud origin feat/42-invoice'
expect blocked 'git push origin +feat/42-invoice'
expect blocked 'git push --delete origin feat/42-invoice'
expect blocked 'git push origin :feat/42-invoice'
expect blocked 'git push --mirror'
expect blocked 'git push --all origin'

# Pushes to a default branch, by name, by full ref, or from it.
expect blocked 'git push origin main'
expect blocked 'git push origin HEAD:main'
expect blocked 'git push origin master'
expect blocked 'git push origin develop'
expect blocked 'git push origin trunk'
expect blocked 'git push origin production'
expect blocked 'git push origin HEAD:refs/heads/main'
expect blocked 'git push origin refs/heads/main'
expect blocked 'git push origin foo:refs/heads/master'
expect blocked 'git push origin release'
expect blocked 'git push origin HEAD:release'
expect blocked 'git push' "$on_main"
expect blocked 'git push -u origin HEAD' "$on_main"
expect blocked 'git push origin $(git branch --show-current)'
expect blocked 'git push origin "$BRANCH"'

# Skipped hooks.
expect blocked 'git push --no-verify -u origin feat/42-invoice'
expect blocked 'git commit --no-verify -m "Add invoice"'
expect blocked 'git commit -n -m "Add invoice"'
expect blocked 'git commit -anm "Add invoice"'
expect blocked 'git -c core.hooksPath=/dev/null commit -m "Add invoice"'
expect blocked 'git -c core.hookspath= push -u origin feat/42-invoice'

# Lost work.
expect blocked 'git reset --hard origin/main'
expect blocked 'git clean -fd'
expect blocked 'git clean -xdf'
expect blocked 'git clean --force'
expect blocked 'git branch -D feat/42-invoice'
expect blocked 'git branch --delete --force feat/42-invoice'
expect blocked 'git branch -df feat/42-invoice'
expect blocked 'git checkout .'
expect blocked 'git checkout -- .'
expect blocked 'git checkout -f main'
expect blocked 'git restore .'
expect blocked 'git restore :/'
expect blocked 'git restore --staged --worktree .'
expect blocked 'git switch -f feat/42-invoice'
expect blocked 'git switch --discard-changes feat/42-invoice'
expect blocked 'git worktree remove --force ../app-42'
expect blocked 'git worktree remove -f ../app-42'
expect blocked 'git stash clear'
expect blocked 'git stash drop'
expect blocked 'git update-ref -d refs/heads/feat/42-invoice'
expect blocked 'git reflog expire --expire=now --all'
expect blocked 'git reflog delete HEAD@{1}'

# Ways around a plain match.
expect blocked '"git" push -f'
expect blocked 'git push "-f"'
expect blocked "git push origin 'main'"
expect blocked 'git push origin "main"'
expect blocked 'g\it push --force'
expect blocked 'bash -c "git push --force"'
expect blocked "sh -c 'git reset --hard'"
expect blocked 'zsh -lc "git clean -fd"'
expect blocked 'eval "git push -f"'
expect blocked '(git push --force)'
expect blocked '( cd ../app && git reset --hard )'
expect blocked '{ git push -f; }'
expect blocked 'echo $(git reset --hard)'
expect blocked 'echo `git stash clear`'
expect blocked 'env GIT_TRACE=1 git push --force'
expect blocked 'GIT_TRACE=1 git push --force'
expect blocked '/usr/bin/git push --force'
expect blocked 'git -C ../app push --force'
expect blocked 'git --git-dir ../app/.git push --force'
expect blocked 'git --work-tree ../app reset --hard'
expect blocked 'git --git-dir=../app/.git push --force'
expect blocked $'git push \\\n  --force origin feat/42-invoice'
expect blocked 'cd ../app && git reset --hard'
expect blocked 'bun run test && git push origin main'
expect blocked 'git log --oneline; git reset --hard'
expect blocked 'git status | cat || git clean -f'
expect blocked $'git status\ngit reset --hard'
expect blocked $'cat <<EOF\nnothing\nEOF\ngit push --force'

# Normal work.
expect allowed 'git push -u origin feat/42-invoice'
expect allowed 'git push origin feat/42-main-menu'
expect allowed 'git push --follow-tags -u origin feat/42-invoice'
expect allowed 'git push -u origin HEAD'
expect allowed 'git push'
expect allowed 'git push -n origin main'
expect allowed 'git push --dry-run --force origin feat/42-invoice'
expect allowed 'git commit -m "Remove the force flag from the form"'
expect allowed 'git commit -m "git push --force is blocked; git reset --hard too"'
expect allowed 'git commit -m "-n is the dry-run flag"'
expect allowed 'git reset --soft HEAD~1'
expect allowed 'git clean -n'
expect allowed 'git clean -fdn'
expect allowed 'git clean --dry-run -fd'
expect allowed 'git branch -d feat/42-invoice'
expect allowed 'git checkout -b feat/42-invoice origin/main'
expect allowed 'git switch -c feat/42-invoice'
expect allowed 'git restore src/lib/invoice.ts'
expect allowed 'git restore --staged .'
expect allowed 'git restore -S .'
expect allowed 'git worktree remove ../app-42'
expect allowed 'git stash list'
expect allowed 'git status --short --branch'
expect allowed 'git -C ../app status'
expect allowed 'gh pr create --base main --title "feat: invoice (#42)" --body-file /tmp/body.md'
expect allowed 'gh pr create --title "x" --body "Never git push --force to main"'
expect allowed 'bun run test'
expect allowed 'echo main'
expect allowed 'echo git push --force origin main'
expect allowed 'printf "%s\n" "git reset --hard"'
expect allowed '# git push --force'
expect allowed $'cat > /tmp/body.md <<\'EOF\'\n## Summary\ngit push --force is now blocked\ngit reset --hard too\nEOF'
expect allowed $'git commit -F - <<EOF\nfeat: block git push --force (#42)\nEOF'
expect allowed 'grep -rn "git clean -fd" docs'

# Input the hook cannot read fails closed.
check blocked "$(run '')" 'empty input'
check blocked "$(run 'not json')" 'malformed input'
check blocked "$(run '{"tool_name":"Bash","tool_input":{}}')" 'no command'
check blocked "$(run '{"tool_name":"Bash","tool_input":{"command":""}}')" 'empty command'

rm -rf "$scratch"
if [ "$failures" -gt 0 ]; then
	echo "$failures failed"
	exit 1
fi
echo "all passed"
