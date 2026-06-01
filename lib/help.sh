#!/usr/bin/env bash

show_help() {
        cat << EOF
Simple Package Manager

A package spec is made up of <package name>-<version>-<release>

Usage: $(basename "$0") [command] [options] [args]

Command: build
Options: -c = run check function (default is to skip checks)
         -b = build but do not create package
         -p = if alreay built, create package
Args: Package spec

Uses $buildroot/<package spec>/$buildfile to create the package.
Once built the install files are tarred and added to the package repository as $pkgroot/<package spec>.$pkgsuffix


Command: install
Options: -y = do not prompt for confirmation to install
         -f = force reinstallation of package
Args: Zero or more package names or specs

Installs one or more packages.  Previously installed versions will be uninstalled prior to installation.

A package name will match the spec with the highest built version number, if that spec is not currently installed.    
A package spec must match a package that is not currently installed (unless option -f is given).
With no arguments the package names of all available packages will be used.


Command: uninstall
Options: -y = do not prompt for confirmation to uninstall
Args: One or more package names or specs

Uninstalls one or more packages.

A package name will match the currently installed version.
A package spec must match the currently installed version.


Command: list
Options: -d = list build directories rather than packages
Args: Zero or one partial or full package spec

Displays a list of all package specs that match the partial spec (as regex partial*).
Installed packages will be prefixed by an asterisk, others a space.

If option -d is specified build directories will be searched for package specs to list.
Build directories that have not been built will be prefixed by ' ', those that have by '+' or '*' if the built package is installed.


Command: <no command>
Options: -v or --version = Display the current version number
         -h or --help = Display this help text
EOF
}


