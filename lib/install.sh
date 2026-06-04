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

create_recovery_log() {
        local ipkgdir=${1:?}
        
        try printf '%s\n' "$@" '===' > "$installroot/$ipkgdir/.spkg/recovery_log"
        die_if $? "writing $installroot/$ipkgdir/.spkg/recovery_log"
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
        local nmetadir="$installroot/$npkgname/.spkg"
        local rmetadir="$installroot/$rpkgname/.spkg"

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
        local ipkgfile="$installroot/$ipkgname/$userfile"
        local sysfile="$sysroot/$userfile"
        local mpkgfile

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

remove_content() {
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

# Check ok to install, create .i_<pkgname> dir and untar package into it
# <pkgspec> <remove pkgspecs...>
prepare_install() {
        declare -g pkgspec ipkgdir

        # Ensure no file clashes (2 package own same file)
        check_install_permissions "$pkgspec" "$@"

        install_tar "$pkgspec" "$ipkgdir"

        # From now on we want to be able to recover installation
        create_recovery_log "$ipkgdir"
}

# We have new package in .i_<pgkname> 
# In recovery mode any section could be run again so must be idempotent
install() {
        declare -g pkgdir ipkgdir upkgdirs
        local upkgdir

        # Run package supplied pre_install and pre_uninstall functions
        pre_install_pkg "$ipkgdir" "${upkgdirs[@]}"

        for upkgdir in "${upkgdirs[@]}"; do
                pre_uninstall_pkg "$upkgdir" "$ipkgdir"
        done

        # If upgrading, prepare a merge package
        if (( ${#upkgdirs[@]} )); then
                # This bit is sensitive to restore problems
                # Cannot just try again as: 
                #  - the merge package contents will change (so can't copy from)
                #  - file system files will target merge package (so can't delete and recreate)
                # As we take recursive copies we have no way to tell
                # if they fully worked or not so:
                #  - recursive copy to .t_<pkgdir>
                #  - then mv to final destination

                try rm -rf "$installroot/.t_$pkgdir"
                if [[ $pkgdir == "${upkgdirs[0]}" ]]; then
                        # pkg1 [+ ...] => pkg1 uses pkg1 as the merge package
                        # so make a copy of original pkg1 as .c_<pkgdir>
                        if [[ ! -d "$installroot/.c_$pkgdir" ]]; then
                                try cp -rd "$installroot/"{,.t_}"$pkgdir"
                                try mv "$installroot/"{.t_,.c_}"$pkgdir"
                        fi
                        upkgdirs[0]=".c_$pkgdir"
                else
                        # pkg1 [+ ...] => pkgn uses new package name as the merge package
                        if [[ -d "$installroot/$pkgdir" ]]; then
                                try cp -rd "$installroot/${upkgdirs[0]}" "$installroot/.t_$pkgdir"
                                try mv "$installroot/"{.t_,}"$pkgdir"
                        fi
                fi
        fi

        # If upgrading, merge additional packages into merge package
        if (( ${#upkgdirs[@]} )); then
                merge_pkgs "$pkgdir" "${upkgdirs[@]}"
        fi

        # Install links/files
        install_content "$ipkgdir" "$pkgdir"
        # Copy forward the list of created directories
        merge_pkgdirs "$ipkgdir" "$pkgdir" 

        # Make install live, exchange .i_pkg1 with old (possibly merged) pkg
        commit_install "$ipkgdir" "$pkgdir"
}

post_install() {
        declare -g pkgdir ipkgdir upkgdirs 

        # Run package supplied post_install function
        post_install_pkg "$pkgdir" "${upkgdirs[@]}"

        # Remove replaced packages, run post_uninstall functions
        # Archive replaced package build and tar files
        remove_content "$ipkgdir"
        for upkgdir in "${upkgdirs[@]}"; do
                if [[ -d "$installroot/$upkgdir" ]]; then
                        post_uninstall_pkg "$upkgdir" "$pkgdir"
                        archive_pkg "$(try cat "$installroot/$upkgdir/.spkg/pkgspec")"
                        rmpkgdir "$upkgdir"
                fi
        done

        #  Tidy up after ourselvers
        [[ $ipkgdir && -d "$installroot/$ipkgdir" ]] && rmpkgdir "$ipkgdir"

        # Install done!
        remove_recovery_log "$pkgdir"
}

install_or_recover_pkg() {
        local start_at=${1:?}
        local pkgspec=${2:?}
        local pkgdir="${pkgspec%-*-*}"
        local ipkgdir=".i_$pkgdir"
        local upkgspec
        declare -a upkgdirs
        
        shift 2
        for upkgspec; do
                upkgdirs+=( "${upkgspec%-*-*}" )
        done

        case $start_at in
                start   ) prepare_install "$@" ;&
                install ) install ;&
                post    ) post_install ;;
                * ) fail "invalid recovery start point: $start_at"
        esac
}

# Only call if there is an <.i_pkg> directory in installroot
# and there is sufficient recovery information
recover_pkg_command() {
        local ipkgdir=${1:?}
        local pkgdir="${ipkgdir:3}"
        local rpkgdir
        declare -a log

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

        
        # Log must have at leat one entry and end with '==='
        if (( 2 > ${#log[@]} || '===' != "${log[-1]}" )); then
                # should never happen due to recovery_required check
                # incomplete log, remove i_pkg and return failure
                try rm -r "$installroot/$ipkgdir"
                return 1
        fi

        info "Recovering partial installation of ${args[0]}"

        # Remove trailing ===
        try unset 'log[-1]'

        if [[ $rpkgdir == $ipkgdir ]];then
                install_or_recover_pkg 'install' "${log[@]}"
        else
                install_or_rcover_pkg 'post' "${log[@]}"
        fi
}

install_pkg() {
        install_or_recover_pkg 'start' "$@"
}

# Print package specs of packages that install of <package spec> should remove
pkg_replaces() {
        local pkgspec=${1:?}
        local rep

        # we need to look at .spkg/replaces file before installing
        while read -r rep; do
                installed_pkg "$rep"
        done < <(try tar xOf "$pkgroot/$pkgspec-$pkgsuffix" "$pkgspec/.spkg/replaces")
}

# Install <package spec> (already checked package exists)
# Removes any installed packages that are being replaced
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
