#!/usr/bin/env bash

list_dir_command() {
        local pkg m

        cd "$buildroot"

        for pkg in $(versort "$1"* 2>/dev/null); do
                if [[ -f $pkgroot/$pkg-$pkgsuffix ]]; then
                        if is_installed "$pkg"; then
                                m='i'
                        else
                                m='p'
                        fi
                else
                        m='d'
                fi

                printf '%s  %s\n' "$m" "$pkg"
        done
}

list_pkg_command() {
        local pkg m

        cd "$pkgroot"

        for pkg in $(versort "$1"*"-$pkgsuffix" 2>/dev/null); do
                pkg=${pkg%-"$pkgsuffix"}

                if is_installed "$pkg"; then
                        m="i"
                else
                        m="p"
                fi

                printf "%s  %s\n" "$m" "$pkg"
        done
}


