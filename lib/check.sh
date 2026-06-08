#!/usr/bin/env bash

# Before attempting to install <pkgspec> <with optional replaced pkgspecs...> check that: 
# - we have write permissions in required directories 
# - linkfiles that belong to pkgspec but are already in the real filesystem
#   link to one of the replaced packages
check_install_permissions() {
        local npkgspec=${1:?}
        local file sysfile dir link ok rpkgspec
        shift
        while read -r file; do
                sysfile="$sysroot/${file#*/}"
                [[ -h $sysfile ]] || continue
                dir="${sysfile%/*}"
                [[ -d $dir ]] || continue
                [[ -w $dir ]] || fail "no write permission to $dir"
                link="$(try readlink "$sysfile")"
                if [[ $link =~ ^$installdir/${npkgspec%-*-*} ]]; then
                        ok=1
                elif (( $# )); then
                        ok=0
                        for rpkgspec; do
                                if [[ $link =~ ^$installdir/${rpkgspec%-*-*} ]]; then
                                        ok=1
                                        break
                                fi
                        done
                fi
                (( $ok )) ||
                        fail "install file is not owned by this package: $sysfile" 
        done < <(try tar -taf "$pkgroot/$npkgspec-$pkgsuffix" --exclude=.spkg)

        for rpkgspec; do
                check_uninstall_permissions "$rpkgspec"
        done
}

# Before attempting uninstall/replacement of <pkgspec> check that:
# - we have write permissions in required directories 
# - linkfiles that are going to be removed/replaced belong to this package
check_uninstall_permissions() {
        local upkgspec=${1:?}
        local upkgname="${upkgspec%-*-*}"
        local file sysfile dir link

        while read -r -d '' file; do
                linkfile="$sysroot/$file"
                [[ -h $linkfile ]] || continue
                dir="${sysfile%/*}"
                [[ -d $dir ]] || continue
                [[ -w $dir ]] || fail "no write permission to $dir"
                link="$(try readlink "$linkfile")"
                [[ $link =~ ^$installdir/$upkgname ]] ||
                        fail "uninstall file is not owned by this package: $linkfile"
        done < <(try find "$installroot/$upkgname" -name .spkg -prune -o -type l,f -printf '%P\0')
}
