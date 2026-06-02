#!/usr/bin/env bash

list_dir_command() {
        local pkg m

        try cd "$buildroot"

        while IFS= read -r pkg; do
                if [[ -f $pkgroot/$pkg-$pkgsuffix ]]; then
                        if is_installed "$pkg"; then
                                m='i'
                        else
                                m='p'
                        fi
                else
                        m='d'
                fi

                try printf '%s  %s\n' "$m" "$pkg"
        done < <(versort "$1"* 2>/dev/null)
}

list_pkg_command() {
        local pkg m

        try cd "$pkgroot"

        while IFS= read -r pkg; do
                pkg=${pkg%-"$pkgsuffix"}

                if is_installed "$pkg"; then
                        m="i"
                else
                        m="p"
                fi

                try printf "%s  %s\n" "$m" "$pkg"
        done < <(versort "$1"*"-$pkgsuffix" 2>/dev/null)
}


