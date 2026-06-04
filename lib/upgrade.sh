#!/usr/bin/env bash

with_upgradefns() {
        local pkgname=${2:?}

        (
                trap 'exit 1' SIGTERM
                unset -f pre_install pre_uninstall post_install post_uninstall
                source_file "$installroot/$pkgname/.spkg/upgradefns"
                call_fn "$@"
        )
}

pre_install_pkg() {
        with_upgradefns 'pre_install' "$@"
}

post_install_pkg() {
        with_upgradefns 'post_install' "$@"
}

pre_uninstall_pkg() {
        with_upgradefns 'pre_uninstall' "$@"
}

post_uninstall_pkg() {
        with_upgradefns 'post_uninstall' "$@"
}
