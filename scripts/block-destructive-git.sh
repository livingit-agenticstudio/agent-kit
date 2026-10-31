#!/bin/bash
# A PreToolUse hook for Bash: blocks git commands that lose work, rewrite shared history or skip the
# repo's hooks. Exit 2 blocks the command and shows the reason to the agent; exit 0 lets it run.
# Pushing a feature branch, committing and every read stay allowed.
#
# The command is split into words the way the shell would (quotes, escapes, ;, &&, |, subshells,
# $(...), backticks, heredocs), so a mention of git in text is not a git command, and quoting a word
# does not hide it. bash -c, sh -c and eval are checked as commands of their own. A command the hook
# cannot read is blocked: it fails closed.

export LC_ALL=C

block() {
	echo "Blocked by the agent-kit git guardrail: $1. If it is really needed, ask the developer to run it themselves." >&2
	exit 2
}

input=$(cat)
[ -n "$input" ] || block "the hook got no input, so the command could not be checked"

# The command and the directory it runs in, from the hook's JSON. jq or python3 when there is one,
# a small reader of JSON strings otherwise.
cmd="" cwd=""
if command -v jq >/dev/null 2>&1; then
	cmd=$(printf '%s' "$input" | jq -er '.tool_input.command | strings') ||
		block "the hook could not read the command"
	cwd=$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)
elif command -v python3 >/dev/null 2>&1; then
	read_json='import json,sys
d=json.load(sys.stdin)
v=d["tool_input"][sys.argv[1]] if sys.argv[1]=="command" else d.get("cwd","")
if not isinstance(v,str): sys.exit(1)
sys.stdout.write(v)'
	cmd=$(printf '%s' "$input" | python3 -I -c "$read_json" command 2>/dev/null) ||
		block "the hook could not read the command"
	cwd=$(printf '%s' "$input" | python3 -I -c "$read_json" cwd 2>/dev/null)
else
	json_field() {
		# The raw value of a top-level or nested string field, unescaped. Fails when there is none.
		local pattern="\"$1\"[[:space:]]*:[[:space:]]*\"(([^\"\\\\]|\\\\.)*)\""
		[[ $input =~ $pattern ]] || return 1
		local raw=${BASH_REMATCH[1]} out="" i=0 c
		while ((i < ${#raw})); do
			c=${raw:i:1}
			if [[ $c == \\ ]]; then
				((i++))
				case ${raw:i:1} in
				n) out+=$'\n' ;;
				t) out+=$'\t' ;;
				r) out+=$'\r' ;;
				*) out+=${raw:i:1} ;;
				esac
			else
				out+=$c
			fi
			((i++))
		done
		printf '%s' "$out"
	}
	cmd=$(json_field command) || block "the hook could not read the command"
	cwd=$(json_field cwd)
fi
[ -n "$cmd" ] || block "the command is empty, so it could not be checked"
[ -d "$cwd" ] || cwd=.

# --- Splitting into commands -------------------------------------------------------------------------

SEP=$'\x1e'
WORDS=()   # the words of every command, each command ended by SEP
QUEUE=()   # text to check as commands of its own: $(...), backticks, bash -c, eval

# The index of the character that closes what opens at $2 in $1: a ( for $(, or a backtick.
closing() {
	local s=$1 i=$(($2 + 1)) n=${#1} depth=1 c
	if [[ ${s:$2:1} == '`' ]]; then
		while ((i < n)); do
			c=${s:i:1}
			[[ $c == \\ ]] && ((i += 2)) && continue
			[[ $c == '`' ]] && echo $i && return
			((i++))
		done
		echo $n
		return
	fi
	while ((i < n)); do
		c=${s:i:1}
		case $c in
		\\) ((i++)) ;;
		"'") while ((++i < n)) && [[ ${s:i:1} != "'" ]]; do :; done ;;
		'"') while ((++i < n)) && [[ ${s:i:1} != '"' ]]; do [[ ${s:i:1} == \\ ]] && ((i++)); done ;;
		'(') ((depth++)) ;;
		')') ((--depth == 0)) && echo $i && return ;;
		esac
		((i++))
	done
	echo $n
}

tokenize() {
	local s=$1 n=${#1} i=0 c j word="" inword=0 drop=0 pos line rest d strip
	local -a heredocs=()
	s=${s//$'\\\n'/}
	n=${#s}
	end_word() {
		if ((inword)); then
			if ((drop)); then drop=0; else WORDS+=("$word"); fi
		fi
		word="" inword=0
	}
	while ((i < n)); do
		c=${s:i:1}
		case $c in
		\\)
			((i++))
			word+=${s:i:1} inword=1
			;;
		"'")
			rest=${s:i+1}
			rest=${rest%%"'"*}
			word+=$rest inword=1
			((i += ${#rest} + 1))
			;;
		'"')
			inword=1
			((i++))
			while ((i < n)) && [[ ${s:i:1} != '"' ]]; do
				c=${s:i:1}
				if [[ $c == \\ ]]; then
					((i++))
					case ${s:i:1} in
					'"' | \\ | '$' | '`') word+=${s:i:1} ;;
					*) word+="\\${s:i:1}" ;;
					esac
				elif [[ $c == '$' && ${s:i+1:1} == '(' ]] || [[ $c == '`' ]]; then
					[[ $c == '$' ]] && ((i++))
					j=$(closing "$s" $i)
					QUEUE+=("${s:i+1:j-i-1}")
					word+="\$(${s:i+1:j-i-1})"
					i=$j
				else
					word+=$c
				fi
				((i++))
			done
			;;
		'$')
			if [[ ${s:i+1:1} == '(' ]]; then
				((i++))
				j=$(closing "$s" $i)
				QUEUE+=("${s:i+1:j-i-1}")
				word+="\$(${s:i+1:j-i-1})" inword=1
				i=$j
			else
				word+=$c inword=1
			fi
			;;
		'`')
			j=$(closing "$s" $i)
			QUEUE+=("${s:i+1:j-i-1}")
			word+="\$(${s:i+1:j-i-1})" inword=1
			i=$j
			;;
		' ' | $'\t')
			end_word
			;;
		$'\n')
			end_word
			WORDS+=("$SEP")
			# The bodies of heredocs opened on this line are text, not commands.
			pos=$((i + 1))
			for d in "${heredocs[@]}"; do
				strip=${d:0:1} d=${d:1}
				while ((pos <= n)); do
					rest=${s:pos}
					line=${rest%%$'\n'*}
					((pos += ${#line} + 1))
					((strip)) && line=${line#"${line%%[!$'\t']*}"}
					[[ $line == "$d" ]] && break
				done
			done
			heredocs=()
			i=$((pos - 1))
			;;
		';' | '&' | '|' | '(' | ')')
			end_word
			WORDS+=("$SEP")
			;;
		'<' | '>')
			end_word
			if [[ ${s:i:3} == '<<<' ]]; then
				((i += 2))
				drop=1
			elif [[ ${s:i:2} == '<<' ]]; then
				((i += 2))
				strip=0
				[[ ${s:i:1} == - ]] && strip=1 && ((i++))
				while [[ ${s:i:1} == ' ' ]]; do ((i++)); done
				d=""
				while ((i < n)) && [[ ${s:i:1} != [[:space:]\;\&\|\<\>\(\)] ]]; do
					[[ ${s:i:1} != [\'\"\\] ]] && d+=${s:i:1}
					((i++))
				done
				heredocs+=("$strip$d")
				((i--))
			else
				while [[ ${s:i+1:1} == [\<\>\&\|] ]]; do ((i++)); done
				drop=1
			fi
			;;
		'#')
			if ((inword)); then
				word+=$c
			else
				rest=${s:i}
				rest=${rest%%$'\n'*}
				((i += ${#rest} - 1))
			fi
			;;
		*)
			word+=$c inword=1
			;;
		esac
		((i++))
	done
	end_word
	WORDS+=("$SEP")
}

# --- What each git command may not do ----------------------------------------------------------------

# Sets LETTERS to the letters of a short-option cluster such as -uf, up to and including the first
# letter that takes a value ($2), and TAKES to 1 when that value is the next word.
short() {
	local a=$1 values=$2 k c
	LETTERS="" TAKES=0
	[[ $a == -[!-]* ]] || return 1
	for ((k = 1; k < ${#a}; k++)); do
		c=${a:k:1}
		LETTERS+=$c
		if [[ -n $values && $values == *"$c"* ]]; then
			((k == ${#a} - 1)) && TAKES=1
			return 0
		fi
	done
	return 0
}

whole_tree() {
	case $1 in
	. | ./ | :/ | :/. | '*' | ':(top)'*) return 0 ;;
	esac
	return 1
}

# The default branches of the repo in $1: origin's HEAD, and the usual names.
default_branches() {
	local head
	DEFAULTS=" main master develop trunk production "
	head=$(git -C "$1" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null) &&
		DEFAULTS+="${head#*/} "
	CURRENT=$(git -C "$1" branch --show-current 2>/dev/null)
}

is_default() {
	[[ $DEFAULTS == *" $1 "* ]]
}

check_push() {
	local dir=$1
	shift
	local a dry=0 force=0 delete=0 all=0 skip=0 r dst
	local -a pos=()
	for a in "$@"; do
		((skip)) && skip=0 && continue
		case $a in
		--dry-run) dry=1 ;;
		--force | --force-with-lease* | --force-if-includes) force=1 ;;
		--mirror | --all | --branches) all=1 ;;
		--delete | --prune) delete=1 ;;
		--repo | --receive-pack | --exec | --push-option) skip=1 ;;
		--*) ;;
		-?*)
			short "$a" o
			[[ $LETTERS == *n* ]] && dry=1
			[[ $LETTERS == *f* ]] && force=1
			[[ $LETTERS == *d* ]] && delete=1
			skip=$TAKES
			;;
		*) pos+=("$a") ;;
		esac
	done
	((dry)) && return
	((force)) && block "a force push"
	((delete)) && block "deleting a remote branch"
	((all)) && block "a push of every branch, the default branch included"
	default_branches "$dir"
	for r in "${pos[@]:1}"; do
		[[ $r == *'$'* ]] && block "a push whose branch is only known when it runs. Name the branch literally"
		[[ $r == +* ]] && block "a force push"
		[[ $r == :* ]] && block "deleting a remote branch"
		dst=${r##*:}
		dst=${dst#refs/heads/}
		[[ $dst == HEAD ]] && dst=$CURRENT
		is_default "$dst" && block "a push to the default branch ($dst)"
	done
	((${#pos[@]} <= 1)) && [[ -n $CURRENT ]] && is_default "$CURRENT" &&
		block "a push from the default branch ($CURRENT)"
	[[ ${pos[0]} == *'$'* ]] && block "a push whose target is only known when it runs"
	return 0
}

check_git() {
	local dir=$cwd a sub i=0 n=$#
	local -a g=("$@")
	# Options before the subcommand, some with a value of their own.
	while ((i < n)) && [[ ${g[i]} == -* ]]; do
		case ${g[i]} in
		-C)
			[[ ${g[i + 1]} == /* ]] && dir=${g[i + 1]} || dir="$cwd/${g[i + 1]}"
			((i += 2))
			;;
		-c)
			[[ ${g[i + 1]} == [Cc][Oo][Rr][Ee].[Hh][Oo][Oo][Kk][Ss][Pp][Aa][Tt][Hh]* ]] &&
				block "a git command that skips the repo's hooks"
			((i += 2))
			;;
		--git-dir | --work-tree | --namespace | --super-prefix | --config-env) ((i += 2)) ;;
		*) ((i++)) ;;
		esac
	done
	((i < n)) || return 0
	sub=${g[i]}
	local -a args=("${g[@]:i+1}")
	local delete=0 force=0 dry=0 staged=0 worktree=0 skip=0
	for a in "${args[@]}"; do
		[[ $a == --no-verify ]] && block "a git command that skips the repo's hooks"
	done

	case $sub in
	push) check_push "$dir" "${args[@]}" ;;
	commit)
		for a in "${args[@]}"; do
			((skip)) && skip=0 && continue
			case $a in
			-m | -F | -c | -C | -t | --message | --file | --author | --date | --template) skip=1 ;;
			--*) ;;
			-?*)
				short "$a" mFcCt
				[[ $LETTERS == *n* ]] && block "a commit that skips the repo's hooks"
				skip=$TAKES
				;;
			esac
		done
		;;
	reset)
		for a in "${args[@]}"; do
			[[ $a == --hard ]] && block "git reset --hard"
		done
		;;
	clean)
		for a in "${args[@]}"; do
			case $a in
			--dry-run) dry=1 ;;
			--force) force=1 ;;
			--*) ;;
			-?*)
				short "$a" e
				[[ $LETTERS == *n* ]] && dry=1
				[[ $LETTERS == *f* ]] && force=1
				;;
			esac
		done
		((force && !dry)) && block "git clean with force"
		;;
	branch)
		for a in "${args[@]}"; do
			case $a in
			--delete) delete=1 ;;
			--force) force=1 ;;
			--*) ;;
			-?*)
				short "$a" u
				[[ $LETTERS == *D* ]] && block "force-deleting a branch"
				[[ $LETTERS == *d* ]] && delete=1
				[[ $LETTERS == *f* ]] && force=1
				;;
			esac
		done
		((delete && force)) && block "force-deleting a branch"
		;;
	checkout)
		for a in "${args[@]}"; do
			((skip)) && skip=0 && continue
			case $a in
			--force) block "a forced checkout" ;;
			--orphan) skip=1 ;;
			--*) ;;
			-?*)
				short "$a" bB
				[[ $LETTERS == *f* ]] && block "a forced checkout"
				skip=$TAKES
				;;
			*) whole_tree "$a" && block "discarding every change in the tree" ;;
			esac
		done
		;;
	restore)
		local -a paths=()
		for a in "${args[@]}"; do
			((skip)) && skip=0 && continue
			case $a in
			--staged) staged=1 ;;
			--worktree) worktree=1 ;;
			--source) skip=1 ;;
			--*) ;;
			-?*)
				short "$a" s
				[[ $LETTERS == *S* ]] && staged=1
				[[ $LETTERS == *W* ]] && worktree=1
				skip=$TAKES
				;;
			*) paths+=("$a") ;;
			esac
		done
		# Only the index changes when --staged comes without --worktree.
		((staged && !worktree)) && return 0
		for a in "${paths[@]}"; do
			whole_tree "$a" && block "discarding every change in the tree"
		done
		;;
	switch)
		for a in "${args[@]}"; do
			((skip)) && skip=0 && continue
			case $a in
			--force | --discard-changes) block "a switch that discards changes" ;;
			--*) ;;
			-?*)
				short "$a" cC
				[[ $LETTERS == *f* ]] && block "a switch that discards changes"
				skip=$TAKES
				;;
			esac
		done
		;;
	worktree)
		if [[ ${args[0]} == remove ]]; then
			for a in "${args[@]:1}"; do
				[[ $a == --force ]] && block "removing a worktree with force"
				short "$a" "" && [[ $LETTERS == *f* ]] && block "removing a worktree with force"
			done
		fi
		;;
	stash)
		[[ ${args[0]} == clear || ${args[0]} == drop ]] && block "dropping stashed work"
		;;
	update-ref)
		for a in "${args[@]}"; do
			[[ $a == -d ]] && block "deleting a ref"
		done
		;;
	reflog)
		[[ ${args[0]} == expire || ${args[0]} == delete ]] && block "deleting reflog entries"
		;;
	esac
	return 0
}

# One command: past variable assignments and wrappers to the program, then by program.
check_command() {
	local i=0 n=$# name a
	local -a w=("$@")
	while ((i < n)); do
		case ${w[i]} in
		[A-Za-z_]*=*) ((i++)) ;;
		env | command | exec | time | nohup | sudo | builtin | '!' | '{' | '}' | then | do | else | elif | if | while | until)
			((i++))
			while ((i < n)) && [[ ${w[i]} == -* ]]; do ((i++)); done
			;;
		*) break ;;
		esac
	done
	((i < n)) || return 0
	name=${w[i]##*/}
	case $name in
	git) check_git "${w[@]:i+1}" ;;
	bash | sh | zsh | dash | ksh)
		for ((i = i + 1; i < n; i++)); do
			a=${w[i]}
			if [[ $a == -[!-]* && $a == *c* ]]; then
				QUEUE+=("${w[i + 1]}")
				return 0
			fi
		done
		;;
	eval) QUEUE+=("${w[*]:i+1}") ;;
	esac
	return 0
}

QUEUE=("$cmd")
q=0
while ((q < ${#QUEUE[@]})); do
	((q > 50)) && block "the command nests too deep to check"
	WORDS=()
	tokenize "${QUEUE[q]}"
	current=()
	for word in "${WORDS[@]}"; do
		if [[ $word == "$SEP" ]]; then
			((${#current[@]})) && check_command "${current[@]}"
			current=()
		else
			current+=("$word")
		fi
	done
	((q++))
done

exit 0
