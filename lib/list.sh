#!/usr/bin/env bash

list_archive_command() {
	list_pkgs 'Y' "$installroot" "$archiveroot/pkg" "$archiveroot/build" "$@"
}

list_pkg_command() {
	list_pkgs 'N' "$installroot" "$pkgroot" "$buildroot" "$@"
}

list_pkgs() {
	local archive=$1
	local idir=$2
	local pdir=$3
	local ddir=$4
	local types=$5
	local query=$6

        declare -A all_pkgs
        declare -a flags pkgs keys
        local pkg pkgspec v flag

	shopt -s nullglob

	flag=0
	[[ $types =~ 'i' ]] && flag=1
	[[ $types =~ 'p' ]] && (( flag+=2 ))
	[[ $types =~ 'd' ]] && (( flag+=4 ))

	if [[ $ddir ]]; then
		pkgs=( $ddir/*$query* )
		for pkg in "${pkgs[@]}"; do
			pkgspec="${pkg##*/}"
			(( all_pkgs[$pkgspec]+=4 ))
		done
	fi

	if [[ $pdir ]]; then
		pkgs=( $pdir/*$query*-$pkgsuffix )
		for pkg in "${pkgs[@]}"; do
			pkgspec="${pkg%-$pkgsuffix}"
			pkgspec="${pkgspec##*/}"
			(( all_pkgs[$pkgspec]+=2 ))
		done
	fi

	if [[ $idir ]]; then
		pkgs=( "$idir/"* )
		for pkg in "${pkgs[@]}"; do
			if [[ -f "$pkg/.spkg/pkgspec" ]]; then
				pkgspec="$(try cat "$pkg/.spkg/pkgspec")"
				if [[ $archive == 'N' || -v all_pkgs[$pkgspec] ]]; then
					[[ $pkgspec =~ .*$query.* ]] && (( all_pkgs[$pkgspec]+=1 ))
				fi
			fi
		done
	fi


	shopt -u nullglob

	(( ${#all_pkgs[@]} )) || return

        keys=( $(try printf "%s\n" "${!all_pkgs[@]}" | try sort -uV) )

	flags=( --- i-- -p- ip- --d i-d -pd ipd )
        for key in "${keys[@]}"; do
                v="${all_pkgs[$key]}"
		(( flag == (v & flag) )) && printf '%s  %s\n' "${flags[v]}" "$key"
        done
}

