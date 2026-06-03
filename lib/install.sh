#!/usr/bin/env bash

# Basic install and upgrade is fairly simple
# Gets more complicated when multiple packages are replaced by one package
# 
# pkg1 ->                       new install
# pkg1 -> pkg1                  simple upgrade
# pkg1 -> pkg2                  upgrade to new name
# pkg1 + pkg2 + ... => pkg1     merge multiple pkgs to original name
# pkg1 + pkg2 + ... => pkgnew   merge multiple pkgs to new name
#
# Important to be able to recover partially complete
# installations as the process is not genrally idempotent.
#
# Progress is tracked in recovery_log metadata file to allow recovery
# from certain points

require 'check' 'upgrade'

recovery_point=0

start_recovery_log() {
        local pkgspec=${1:?}
        local pkgdir=".i_${pkgspec%-*-*}"
        
        try printf '%s\n' "$@" > "$installroot/$pkgdir/.spkg/recovery_log"
        set_recovery_point 1 "$pkgdir"
}

set_recovery_point() {
        local pt=${1:?}
        local pkgdir=${2:?}

        try printf "%s\n" $pt >> "$installroot/$pkgdir/.spkg/recovery_log"
        die_if $? "writing $installroot/$pkgdir/.spkg/recovery_log"

        recovery_point=$pt
}

remove_recovery_log() {
        local pkgdir=${1:?}

        try rm -f "$installroot/$pkgdir/.spkg/recovery_log"
}

install_tar() {
        local pkgspec=${1:?}
        local pkgdir=${2:?}

        try rm -rf "$installroot/$pkgdir"
        trace mkdir -pv "$installroot/$pkgdir"
        try tar xaf "$pkgroot/$pkgspec-$pkgsuffix" \
                --strip-components=1 \
                -C "$installroot/$pkgdir"
}

merge_metadata() {
        local npkgname=${1:?}
        local rpkgname=${2:?}
        local metafile=${3:?}
        local nmetadir rmetadir
        nmetadir="$installroot/$npkgname/.spkg"
        rmetadir="$installroot/$rpkgname/.spkg"

        try cat "$nmetadir/$metafile"  "$rmetadir/$metafile" | 
                try uniq > "$nmetadir/$metafile.merged"
        try mv "$nmetadir/$metafile.merged" "$nmetadir/$metafile"
}

# Merge into <pkgdir> files from <other replaced pkgdirs>
# All linkfiles are modified to target the files in the merged package
merge_pkgs() {
        local mpkgname=${1:?}
        local mpkgdir rpkgname rpkgdir linkfile targetfile metafile

        shift
        (( $# != 0 )) || return 0

        # Skip first replaced pkg as content will already be in merge dir
        shift

        mpkgdir="$installroot/$mpkgname"
        for rpkgname; do
                rpkgdir="$installroot/$rpkgname"
                # merge in contents of other replaced packages
                try tar cf - -C "$rpkgdir" --exclude=.spkg . | 
                        try tar xf - -C "$mpkgdir"
                for metafile in reqdirs pkgfiles pkgdirs userfiles; do
                        merge_metadata "$mpkgname" "$rpkgname" "$metafile"
                done
        done

        # Relink files to point to same file but in the merged package
        while IFS= read -r file; do
                linkfile="$sysroot/$file"
                [[ -h $linkfile ]] || continue
                targetfile="$installdir/$mpkgname/$file"
                [[ $targetfile != "$(try readlink "$linkfile")" ]] || continue
                trace ln -svf "$targetfile" "$linkfile"
        done < "$mpkgdir/.spkg/pkgfiles"

        die_if $? "reading $mpkgdir/.spkg/pkgfiles"
}

# Capture any required dirs that we will create on install
# for potential removal when package is uninstalled
#
# Create any missing dirs one by one so we can set correct permissions
install_reqdirs() {
        local ipkgname=${1:?}
        local ipkgdir="$installroot/$ipkgname"

        while IFS= read -r d; do
                sysdir="$sysroot/$d"
                [[ ! -d $sysdir ]] || continue
                try printf "%s\n" "$d"
                mode="$(try stat -c%a "$ipkgdir/$d")"
                trace mkdir -vm "$mode" "$sysdir"
        done < "$ipkgdir/.spkg/reqdirs" > "$ipkgdir/.spkg/pkgdirs"

        die_if $? "reading $ipkgdir/.spkg/reqdirs"
}

# Create any linkfiles that are new in this package
# <name of install pkg directory> <name of package> 
install_pkgfiles() {
        local ipkgname=${1:?}
        local pkgname=${2:?}
        local file linkfile targetfile

        while IFS= read -r file; do
                linkfile="$sysroot/$file"
                [[ ! -h $linkfile ]] || continue
                targetfile="$installdir/$pkgname/$file"
                trace ln -svf "$targetfile" "$linkfile"
        done < "$installroot/$ipkgname/.spkg/pkgfiles"

        die_if $? "reading $installroot/$ipkgname/.spkg/pkgfiles"
}

# Install user files for install package  
# <merged package name> contains all files being uninstalled
install_userfile() {
        local userfile=${1:?}
        local ipkgname=${2:?}
        local mpkgname=$3

        ipkgfile="$installroot/$ipkgname/$userfile"
        sysfile="$sysroot/$userfile"

        # If system user file does not exist, copy in new one
        if [[ ! -f "$sysfile" ]]; then
                trace cp -v "$ipkgfile" "$sysfile"
                return
        fi

        # If new file = current user file, no change required
        if cmp -s "$ipkgfile" "$sysfile"; then
                return
        fi

        # Look for previous installed version of file
        # If new file = old file, leave the system user file in place 
        # If system user file = old file, replace with new file
        # Note: all replaced package files will have been merged into
        #       first one so only check there
        if [[ $mpkgname ]]; then
                mpkgfile="$installroot/$mpkgname/$userfile"
                if cmp -s "$ipkgfile" "$mpkgfile"; then
                        return
                fi
                if cmp -s "$sysfile" "$mpkgfile"; then
                        trace cp -v "$ipkgfile" "$sysfile"
                        return
                fi
        fi

        # We have a clash so copy in the new file with .spkgnew suffix 
        trace cp -v "$ipkgfile" "$sysfile.spkgnew"
}

install_userfiles() {
        local ipkgname=${1:?}
        local mpkgname=$2
        local metadir="$installroot/$ipkgname/.spkg"
        local userfile

        while IFS= read -r userfile; do
                install_userfile "$userfile" "$ipkgname" "$mpkgname"
        done < "$metadir/userfiles"

        die_if $? "reading $metadir/userfiles"
}

install_content() {
        local ipkgname=${1:?}
        local pkgname=${2:?}

        install_reqdirs "$ipkgname"
        install_pkgfiles "$ipkgname" "$pkgname"
        install_userfiles  "$ipkgname" "$pkgname"
}

# When upgrading the list of created directories need to
# be copied into the new package
merge_pkgdirs() {
        local ipkgname=${1:?}
        local mpkgname=${2:?}

        [[ -d "$installroot/$mpkgname" ]] &&
                merge_metadata "$ipkgname" "$mpkgname" 'pkgdirs'
}

# Make the install package the live package
# <name of install pkg dir> <name of live package dir>
commit_install() {
        local ipkgdir=${1:?}
        local pkgdir=${2:?}
        local exchange

        [[ -d "$installroot/$pkgdir" ]] && exchange="--exchange"

        trace mv -vT $exchange "$installroot/$ipkgdir" "$installroot/$pkgdir"
}

uninstall_content() {
        local xpkgdir=$1
        local file link

        [[ -d "$installroot/$xpkgdir" ]] || return

        while IFS= read -r file; do
                [[ -h "$sysroot/$file" ]] || continue
                link="$(try readlink "$sysroot/$file")"
                [[ ! -e "${sysroot}$link" ]] || continue
                trace rm -v "$sysroot/$file"
        done < "$installroot/$xpkgdir/.spkg/pkgfiles"

        die_if $? "reading $installroot/$xpkgdir/.spkg/pkgfiles"
}


# Install is ok if nothing crashes
# but if there is a crash for some reason, recovery is non-trivial
# recovery info and recovery_point is saved as we proceed to enable restart
# The recovery log is stored in the package to be installed
# which, after commit_install, becomes the package that has been installed
install_recover_pkg() {
        local recovery_point=${1:?}
        local pkgspec=${2:?}
        local pkgdir="${pkgspec%-*-*}"
        local ipkgdir=".i_$pkgdir"
        local upkgspec
        declare -a upkgdirs

        shift 2
        for upkgspec; do
                upkgdirs+=( "${upkgspec%-*-*}" )
        done

        if (( recovery_point == 0 )); then
                # Ensure no file clashes (2 package own same file)
                check_install_permissions "$pkgspec" "$@"

                # Create .i_pkg directory and add content from pkg far file 
                install_tar "$pkgspec" "$ipkgdir"

                # From now on we want to be able to recover installation
                start_recovery_log "$pkgspec" "$@"
        fi

        if (( recovery_point == 1 )); then
                # Run package supplied pre-install and pre_uninstall functions
                pre_install_pkg "$ipkgdir" "${upkgdirs[@]}"

                for upkgdir in "${upkgdirs[@]}"; do
                        pre_uninstall_pkg "$upkgdir" "$ipkgdir"
                done
                set_recovery_point 2 "$ipkgdir"
        fi

        if (( recovery_point == 2 )); then
                # If upgrading, prepare a merge package
                if (( ${#upkgdirs[@]} )); then
                        if [[ $pkgdir == "${upkgdirs[0]}" ]]; then
                                # pkg1 [+ ...] => pkg1 uses pkg1 as the merge package
                                # so make a copy of original pkg1
                                try cp -rd "$installroot/"{,.c_}"$pkgdir"
                                upkgdirs[0]=".c_$pkgdir"
                        else
                                # pkg1 [+ ...] => pkgn uses new package name as the merge package
                                try cp -rd "$installroot/${upkgdirs[0]}" "$installroot/$pkgdir"
                        fi
                fi
                set_recovery_point 3 "$ipkgdir"
        fi

        if (( recovery_point == 3 )); then
                # If upgrading, merge additional packages into merge package
                if (( ${#upkgdirs[@]} )); then
                        merge_pkgs "$pkgdir" "${upkgdirs[@]}"
                fi
                set_recovery_point 4 "$ipkgdir"
        fi

        if (( recovery_point == 4 )); then
                # Install links/files
                install_content "$ipkgdir" "$pkgdir"
                # Copy forward the list of created directories
                merge_pkgdirs "$ipkgdir" "$pkgdir" 

                set_recovery_point 5 "$ipkgdir"
        fi

        if (( recovery_point == 5 )); then
                # Make install live, exchange .i_pkg1 with old (possibly merged) pkg
                commit_install "$ipkgdir" "$pkgdir"
                set_recovery_point 6 "$pkgdir"
        fi

        if (( recovery_point == 6 )); then
                # Run package supplied post_install and post_uninstall functions
                post_install_pkg "$pkgdir" "${upkgdirs[@]}"
                set_recovery_point 7 "$pkgdir"
        fi

        if (( recovery_point == 7 )); then
                uninstall_content "$ipkgdir"
                for upkgdir in "${upkgdirs[@]}"; do
                        if [[ -d "$installroot/$upkgdir" ]]; then
                                post_uninstall_pkg "$upkgdir" "$pkgdir"
                                archive_pkg "$(try cat "$installroot/$upkgdir/.spkg/pkgspec")"
                                rmpkgdir "$upkgdir"
                        fi
                done
                set_recovery_point 8 "$pkgdir"
        fi

        #  Tidy up after ourselvers
        [[ $ipkgdir && -d "$installroot/$ipkgdir" ]] && rmpkgdir "$ipkgdir"

        # Install done!
        remove_recovery_log "$pkgdir"
}

install_pkg() {
        install_recover_pkg 0 "$@"
}

# Only call if there is an <.i_pkg> directory in installroot
# and there is sufficient recovery information
recover_pkg_command() {
        local ipkgdir=${1:?}
        local pkgdir="${ipkgdir:3}"
        local rpkgdir entry recovery_pt
        declare -a args log

        if [[ -f "$installroot/$ipkgdir/.spkg/recovery_log" ]]; then
                rpkgdir="$ipkgdir"
        elif [[ -f "$installroot/$pkgdir/.spkg/recovery_log" ]]; then
                rpkgdir="$pkgdir"
        else
                # should never happen due to recovery_required check
                # no recovery log, remove ipkgdir (if exists) and return failure
                try rm -rf "$installroot/$ipkgdir"
                return 1
        fi

        try readarray -t log < "$installroot/$rpkgdir/.spkg/recovery_log"

        die_if $? "reading $installroot/$rpkgdir/.spkg/recovery_log"

        
        for entry in "${log[@]}"; do
                [[ ! $entry =~ ^[1-8]$ ]] || break 
                args+=( "$entry" )
        done

        # Log must have at least one arg and one recovery_point
        if (( 2 > ${#log[@]} || ${#log[@]} == ${#args[@]} )); then
                # should never happen due to recovery_required check
                # incomplete log, remove i_pkg and return failure
                try rm -r "$installroot/$ipkgdir"
                return 1
        fi

        info "Recovering partial installation of ${args[0]}"

        recovery_pt=${log[-1]}
        install_recover_pkg $recovery_pt "${args[@]}"
}


# Install <package spec> (already checked package exists)
# Uninstalls any installed packages that are being replaced
install_pkg_command() {
        local pkgspec=${1:?}
        declare -a upkgspecs 
        local upkgspec

        try readarray -t upkgspecs < <(pkg_replaces "$pkgspec")
        
        info "Installing $pkgspec"
        for upkgspec in "${upkgspecs[@]}"; do
                info "Removing $upkgspec"
        done

        install_pkg "$pkgspec" "${upkgspecs[@]}"
}
