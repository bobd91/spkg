#!/usr/bin/env bash

build_pkg() {
        local pkg=$1
        local opt_check=$2
        local opt_build_only=$3
        local opt_package_only=$4

        local builddir=$buildroot/$pkg
        local pkgfile="$pkgroot/$pkg-$pkgsuffix"
        local srcdir=$builddir/src
        local pkgdir=$builddir/pkg/$pkg
        local i src md5 link fn f url
        # declare variables that should be set by $buildfile
        declare -a sources md5sums userfiles replaces
        local pkgname pkgver pkgrel 
        # shellcheck disable=SC2034 # maybe defined in $buildfile
        local build check package 
        # shellcheck disable=SC2034 # maybe defined in $buildfile
        local pre_install post_install pre_uninstall post_uninstall


        [[ ! -f $pkgfile ]] || fail "package already exists $pkgfile"
        [[ -d $builddir ]] || fail "missing build directory $builddir"
        [[ -f $builddir/$buildfile ]] || fail "missing $buildfile in build directory $builddir"

        try cd "$builddir"
        
        # defaults, can be added to or overridden by $buildfile
        local userfiles=("/etc/*")
        local replaces=("${pkg%-*-*}")

        source_file "$buildfile"

        [[ "$pkg" == "$pkgname-$pkgver-$pkgrel" ]] || fail "build is not for $pkg"

        if (( ! $opt_package_only )); then

                (( ${#sources[@]} == "${#md5sums[@]}" )) || fail "wrong number of md5sums $pkg" 

                try rm -rf src pkg
                try mkdir src
                try mkdir -p "pkg/$pkg"

                for i in "${!sources[@]}"; do
                        src=${sources[$i]}
                        md5=${md5sums[$i]}
                        if [[ $src =~ ^https:// ]]; then
                                url=$src
                                src=$srcroot/${url##*/}
                                if [[ ! -f "$src" ]]; then
                                        if command -v curl; then
                                                try curl -O --output-dir "$srcroot" "$url"
                                        elif command -v wget; then
                                                try wget -P "$srcroot" "$url"
                                        fi
                                fi
                        elif [[ $src =~ ^/ ]]; then
                                src=${sysroot}$src
                        else
                                src=$srcroot/$src
                        fi

                        [[ -f $src ]] || fail "source not found $src"
                        [[ $(try md5sum "$src") == "$md5  $src" ]] || fail "incorrect md5sum for $src"  

                        # only untar the first source file
                        # it may not be a tar file so don't exit on error
                        if (( i )) || ! tar xaf "$src" -C src 2>/dev/null; then
                                try cp -r "$src" src
                        fi
                done

                try cd "$srcdir"
                call_fn build
                if (( $opt_check )); then
                        call_fn check
                fi
                call_fn package
        else
                if [[ ! ( -d $srcdir && -d $pkgdir ) ]]; then
                        fail "cannot add package, package not built"
                fi
        fi

        if (( ! $opt_build_only )); then
                try cd "$pkgdir"

                # sanity check, symlinks must not point back into spkg directories
                while IFS= read -r -d '' link; do
                        if [[ $(readlink "$link") =~ $libdir ]]; then
                                fail "cannot package: '${link#"$pkgdir"/}' is a symlink into ${libdir:1}"
                        fi
                done < <(try find "$pkgdir" -type l -print0)

                # Try and spot other references to spkg directories
                # Except spkg package of course!
                if [[ $pkgname != 'spkg' ]] && grep -r "$libdir" > /dev/null; then
                        warn "some package files contain references to ${libdir:1}"
                fi

                try mkdir .spkg

                {
                        for fn in pre_install post_install pre_uninstall post_uninstall; do
                                type $fn 2> /dev/null | try tail -n +2
                        done
                } > .spkg/upgradefns

                {
                        for f in "${userfiles[@]}"; do
                                [[ ${f::1} == '/' ]] || fail "userfiles must be absolute paths"
                                try find . -path ".$f" -type f -printf "%P\n"
                        done
                } > .spkg/userfiles

                # turn on dotglob so we get ALL files and dirs
                try shopt -s dotglob
                try find -- * -name .spkg -prune -o -type f -print |
                        try grep -vxFf .spkg/userfiles > .spkg/pkgfiles
                try find -- * -name .spkg -prune -o -type d -print > .spkg/reqdirs
                try shopt -u dotglob
                
                try touch .spkg/pkgdirs
                try printf '%s\n' "${replaces[@]}" > .spkg/replaces
                try echo "$pkg" > .spkg/pkgspec

                try cd "$builddir"

                try tar caf "$pkgfile" -C "$builddir/pkg" "$pkg"

                try rm -rf src pkg
        fi
}


