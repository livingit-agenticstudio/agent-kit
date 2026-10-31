#!/bin/bash
# A PreToolUse hook for Bash: blocks git commands that lose work, rewrite shared history or skip the
# repo's checks. Exit 2 blocks the command and shows the reason to the agent; exit 0 lets it run.
# Pushing a branch, committing and every read stay allowed.

input=$(cat)

# The command from the hook's JSON. jq or python3 when there is one, a plain unescape otherwise.
if command -v jq >/dev/null 2>&1; then
	cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
elif command -v python3 >/dev/null 2>&1; then
	cmd=$(printf '%s' "$input" | python3 -I -c 'import json,sys; print(json.load(sys.stdin).get("tool_input", {}).get("command", ""))')
else
	pattern='"command"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)"'
	cmd=""
	if [[ $input =~ $pattern ]]; then
		cmd=${BASH_REMATCH[1]//\\\"/\"}
		cmd=${cmd//\\\\/\\}
	fi
fi

block() {
	echo "Blocked by the agent-kit git guardrail: $1. It can lose work, rewrite shared history or skip a check. If it is really needed, ask the developer to run it themselves." >&2
	exit 2
}

# A short flag cluster such as -uf or -xdf that holds the given letter.
has_short() {
	[[ $1 =~ ^-[a-zA-Z]+$ && $1 == *"$2"* ]]
}

check() {
	local -a words
	read -ra words <<<"$1"
	local i=0 n=${#words[@]}
	# Find git, then its subcommand, past `-C <dir>`, `-c <key=value>` and other global flags.
	while ((i < n)) && [[ ${words[i]} != git && ${words[i]} != */git ]]; do ((i++)); done
	((i < n)) || return 0
	((i++))
	while ((i < n)) && [[ ${words[i]} == -* ]]; do
		[[ ${words[i]} == -C || ${words[i]} == -c ]] && ((i++))
		((i++))
	done
	((i < n)) || return 0
	local sub=${words[i]}
	local -a args=("${words[@]:i+1}")
	local a delete=0 force=0

	case $sub in
	push)
		for a in "${args[@]}"; do
			case $a in
			--force | --force-with-lease* | --force-if-includes) block "a force push" ;;
			--mirror) block "a mirror push" ;;
			--delete | -d) block "deleting a remote branch" ;;
			--no-verify) block "a push that skips the repo's hooks" ;;
			+* | :*) block "a push that rewrites or deletes a remote branch" ;;
			main | master | *:main | *:master) block "a push to the default branch" ;;
			esac
			has_short "$a" f && block "a force push"
		done
		;;
	commit)
		for a in "${args[@]}"; do
			[[ $a == --no-verify ]] && block "a commit that skips the repo's hooks"
		done
		;;
	reset)
		for a in "${args[@]}"; do
			[[ $a == --hard ]] && block "git reset --hard"
		done
		;;
	clean)
		for a in "${args[@]}"; do
			[[ $a == --force ]] && block "git clean with force"
			has_short "$a" f && block "git clean with force"
		done
		;;
	branch)
		for a in "${args[@]}"; do
			case $a in
			--delete) delete=1 ;;
			--force) force=1 ;;
			esac
			has_short "$a" D && block "force-deleting a branch"
			has_short "$a" d && delete=1
			has_short "$a" f && force=1
		done
		((delete && force)) && block "force-deleting a branch"
		;;
	checkout)
		for a in "${args[@]}"; do
			[[ $a == . ]] && block "discarding every change in the tree"
			[[ $a == --force ]] && block "a forced checkout"
			has_short "$a" f && block "a forced checkout"
		done
		;;
	restore)
		for a in "${args[@]}"; do
			[[ $a == . ]] && block "discarding every change in the tree"
		done
		;;
	stash)
		[[ ${args[0]} == clear || ${args[0]} == drop ]] && block "dropping stashed work"
		;;
	esac
	return 0
}

# One git invocation per segment of a compound command.
nl=$'\n'
cmd=${cmd//&&/$nl}
cmd=${cmd//||/$nl}
cmd=${cmd//;/$nl}
cmd=${cmd//|/$nl}
while IFS= read -r segment; do
	check "$segment"
done <<<"$cmd"

exit 0
