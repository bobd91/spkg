#!/usr/bin/env bash

require 'check' 'upgrade'

# Uninstalling <package>, remove userfile if unchanged since installation
uninstall_userfile() {
        local userfile=${1:?}
        local pkgname=${2:?}
        local pkgdir="$installroot/$pkgname"

        if cmp -s "$pkgdir/$userfile" "$sysroot/$userfile"; then
                trace rm -v "$sysroot/$userfile"
        fi
}

uninstall_userfiles() {
        local pkgname=${1:?}
        local metadir="$installroot/$pkgname/.spkg"
        local userfile

        while IFS= read -r userfile; do
                uninstall_userfile "$userfile" "$pkgname"
        done < "$metadir/userfiles"

        die_if $? "reading $metadir/userfiles"
}
# Uninstall any directories that this <package>
# created when installed and are now empty
uninstall_pkgdirs() {
        local pkgname=${1:?}
        local d

        # Remove in reverse order, for example a/b before a
        while IFS= read -r d; do
                trace rmdir -v --ignore-fail-on-non-empty "$sysroot/$d"
        done < <(try tac "$installroot/$pkgname/.spgk/pkgdirs")
}

# Remove all linkfiles from system for <package> pkgfiles
# Only remove if they symlink to the expected place
# [should always be the case but don't compound errors
# by deleting files being relied upon]
uninstall_pkgfiles() {
        local pkgname=${1:?}
        local pkgdir="$installroot/$pkgname"
        local file linkfile targetfile

        while IFS= read -r file; do
                linkfile="$sysroot/$file"
                [[ -h $linkfile ]] || continue
                targetfile="$installdir/$pkgname/$file"
                [[ $targetfile == "$(try readlink "$linkfile")" ]] || continue 
                trace rm -v "$linkfile"
        done < "$pkgdir/.spkg/pkgfiles"

        die_if $? "reading $pkgdir/.spkg/pkgfiles"
}

uninstall_pkg() {
        uninstall_pkgfiles "$@"
        uninstall_userfiles "$@"
        uninstall_pkgdirs "$@"
}

uninstall_pkg_command() {
        local pkgspec=${1:?}
        local pkgname="${pkgspec%-*-*}"

        info "Uninstalling $pkgspec"

        check_uninstall_permissions "$pkgspec"

        pre_uninstall_pkg "$pkgname"
        uninstall_pkg "$pkgname"
        post_uninstall_pkg "$pkgname"

        archive_pkg "$pkgspec"

        rmpkgdir "$pkgname"
}

