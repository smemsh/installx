#!/usr/bin/env bash
#
# installx: installx, installrc
#   installs exe files and in-dir exelinks, or all .rclinks, to [homedir]
#
# desc:
#  - installx: cp exefiles & symlinks to in-dir exes: ${1:-./} -> ${2:-~/bin/}
#  - installrc: cp .rclinks as: ${1:-.}/.rclink -> ${2:-~/${PWD##*/}}/target
#  - (see process_args() for invocation options)
#
# scott@smemsh.net
# https://github.com/smemsh/utilsh/
# https://spdx.org/licenses/GPL-2.0
#
##############################################################################

invname=${0##*/}

findbase="find -mindepth 1 -maxdepth 1"
files="-type f"
flinks="-xtype f"
links="-type l -not -lname */*"
exes="-executable" # unlike -perm -01, uses referent if symlink
dots="-name .*"

usagex ()
{
	cat <<- % >&2
	$invname: args: [<srcdir> <dstdir>]
	$invname: default: src:./ exe:~/bin/ rc:~/
	$invname: options:
	%
	# you'd think this grep doesn't need the '.*' parts if you look
	# at the source but remember it's bash prettification we grep
	#
	declare -f process_args \
	| grep -oP -- '-\w.*\|.*--[\w-]+' \
	| sed s,^,\\t, \
	>&2

	false; exit
}

process_args ()
{
	local yn
	local -a opts
	declare -g src dst dryrun
	declare -ag cmd
	declare -g ask=1 # default if unforced confirm

	eval set -- $(getopt -n $invname \
	-o qfnh -l quiet,force,test,help -- "$@")
	while true; do case $1 in
	(-n|--test) dryrun=1; shift;;
	(-q|--quiet) quiet=1; shift;;
	(-f|--force) ask=0; shift;;
	(-h|--help) usagex;;
	(--) shift; break;;
	(*) usagex;;
	esac; done

	if ! (($# == 0 || $# == 2)); then
		usagex; fi

	if ((quiet && ask)); then
		echo "quiet mode cannot be interactive" >&2; false; exit; fi
	if ((dryrun && force)); then
		echo "the force is not with you" >&2; false; exit; fi

	# where to get the files, defaults to the invocation dir
	#
	src="${1:-${PWD:?}}"

	# where to put the files
	# - last arg to single 'cp' if installing executables
	# - dirname component of last arg to each 'ln' if installing rclinks
	#
	dst="${2:-${HOME:?}}"

	# we're going to chdir, and we test -d later (but can be -L also)
	# so we'll just follow it if it's a link, should have no effect
	#
	dst="${dst%/}"
	src="${src%/}"

	if [[ $invname == installx && ! $2 ]]; then
		dst="$dst/bin"; fi

	if ((ask)); then
		read -n 1 -p "overwrite in '$dst/' with '$src/*' (y/n)? " yn; echo
		if [[ $yn != 'y' ]]; then
			echo "aborting"; false; exit; fi
	fi
}

check_sanity ()
{
	if ! test -d "$dst"; then
		if ! mkdir -p "$dst"; then
			echo "dest '$dst/' dne or bad mkdir" >&2; exit; fi; fi

	if ! test -d "$src"; then
		echo "source dir invalid" >&2; false; exit; fi

	if ! test -w "$dst"; then
		echo "cannot write to dstdir '$dst/'" >&2; false; exit; fi
}


print_execution_stats ()
{
	local which
	local already

	local src="$src/"
	local dst="$dst/"

	pluralize ()
	{
		printf $1
		if (($2 == 0 || $2 > 1)); then
			printf 's'; fi
	}

	if [[ $src$dst =~ [^a-zA-Z0-9_/.+,:@-] ]]
	then src="\"$src\"" dst="\"$dst\""; fi

	echo "${dryrun:+testmode: }$src -> $dst"

	printf "${dryrun:+testmode: }installed "
	for which in script exelink rclink; do
		eval count="\${#${which}_names[@]}"
		((count)) || continue
		((already++)) && printf ", "
		printf "$count `pluralize $which $count`"
	done

	if ((already == 0)); then
		printf "nothing"; fi
	echo
}

# reads zero-delimited records from find command "$2"
# command into array named $1 (declared before calling us)
#
find_into ()
{
	local field
	local what=$1
	local findargs="$2"

	local findprint="-printf %P\\0%l\\0" # %l is empty if not symlink
	local findcmd="$findbase $findargs $findprint"

	# keep getting name-ref field pairs
	#  ref is empty when not a symlink (name\0\0), but still
	#  exists as a delimited field, so it counts correctly
	#  and proper offsets are retained in the loop for links
	#  and non-links
	#
	while true
	do
		for which in names refs
		do
			read -d $'\0' field || break 2
			eval ${what}_${which}+=\(\"\$field\"\)
		done
	done < <(set -f; $findcmd)
}

# todo: not called yet, use it to replace 'ln -r' and to make a list ourselves
pyrelpath ()
{
	:
	#python -c 'import os, sys; print(os.path.relpath(*sys.argv[1:]))'
	#python -c 'import os, sys; print(os.path.relpath(sys.argv[1]))'
}

cmd ()
{
	if ((dryrun)); then
		echo "testmode: '$@'" && return
	elif ! "$@"; then
		echo "$1: failed" >&2; false; exit; fi
}

##############################################################################

installx ()
{
	find_into script "$files $exes";
	find_into exelink "$links $flinks $exes"

	local -a srcfiles=("${script_names[@]}" "${exelink_names[@]}")

	if ((${#srcfiles[@]} == 0)); then
		((quiet)) || echo "no files to copy, skipping"; return; fi

	cmd cp \
		--archive \
		--remove-destination \
		"${srcfiles[@]}" \
		"$dst/" \
	;
}

installrc ()
{
	find_into rclink "$links $dots $flinks -not $exes"

	local n=${#rclink_names[@]}
	for ((i = 0; i < n; i++)); do
		name="${rclink_names[i]}"
		ref="${rclink_refs[i]}"
		
		# bug with u14 vs u16 ln --relative, it does not work right on
		# u14, but does if we remove the link first instead of just
		# using --force flag, see for details:
		# https://bugs.launchpad.net/ubuntu/+source/coreutils/+bug/1715753
		#
		# this is what we're seeing:
		#   $ loop=0; nloops=4; base=/tmp/lntest; \
		#     rm -rf $base/ && mkdir -p $base/dir && \
		#     touch $base/dir/file &&
		#     while ((loop++ < nloops)); do
		#         ln -frs $base/dir/file $base/link
		#         readlink -f $base/link
		#         sleep 1
		#     done
		# /tmp/lntest/dir/file
		# /tmp/lntest/file
		# /tmp/lntest/dir/file
		# /tmp/lntest/file
		#
		# removing it first fixes the issue on u14 but this will all be
		# taken care of once we do this ourselves (see pyrelpath())
		#
		cmd rm -f "$dst/$name"
		cmd ln -rsf "$src/$ref" "$dst/$name"
	done
}

##############################################################################

main ()
{
	process_args "$@" || exit
	check_sanity || exit

	cd "$src" || exit

	if [[ $(declare -F $invname) ]]
	then $invname "$@"
	else echo "unimplemented command '$invname'" >&2; fi

	if ((! quiet)); then
		print_execution_stats; fi
}

main "$@"
