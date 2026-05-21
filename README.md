# spkg
Simple Package Manager

## Introduction

A package manager for a Linux from Scratch or similar DIY Linux system.

Much of the documentation assumes that you are managing an LFS system but it should be
straightforward to follow even if you are not.

Using spkg can help by:
 - saving build instructions for later (re)use
 - using build instructions to create packages
 - saving packages for later installation
 - keeping track of what is installed
 - allowing upgrade or removal of installed packages

It does not:
 - manage package dependencies
 - support a centralised package repository
 - prevent you from doing anything stupid

Preferably spkg will be used from the very start of a new system build allowing all installed software to be managed, but it can be installed later and used for new and upgraded packages.
Comprised of a Bash script and a config file it has no dependencies beyond those specified for a LFS build.

For those building a new LFS system a companion program, lfs2spkg, can be used to produce spkg build
files from the LFS Book source.  This does not do everything for you but does avoid the majority of typing in build instructions.

## Bootstrap

Installing a package manager when you don't have a package manager poses some problems.

In this case a temporary version is installed which is then used to install the final version.
In a pre-chroot environment the temporary version is installed in $LFS/tools/bin and is used
until the chroot environment is entered.

Download the latest spkg tar file to source file dirctory, check the md5sum, untar and cd into the spkg directory

If spkg is being installed pre-chroot

./configure --prefix=$LFS/tools --exec-prefix=$LFS/tools/bin --with-sysroot=$LFS
make install

If installed on a chrooted (or finished) system

./configure
make install

Additional options can be passed to configure, defaults shown in []
 --srccache=[/sources] # where source tarballs are stored
 --installdir=[/spkg]  # where installed packages are stored

(The introduction of a new directory (/spkg) at the root level may seem odd but an explanation will be given below.  You can change it if you do not like it.)


spkg should now be in the PATH so use it to install itself, this also provides a sanity check that it works.

List build directories, if prefixed by a space then they have not been built
spkg list -d
  spkg-1.0.0-1

Build the spkg package
spkg build spkg-1.0.0-1

List packages, if prefixed by a space then they have not been installed
spkg list
  spkg-1.0.0-1

spkg install spkg

List packages, if prefixed by an asterisk then they have been installed
spkg list
* spkg-1.0.0-1

Look at the installed files
ls -l $LFS/usr/bin
ls -l $LFS/etc

These directory listings show how spkg handles different types of file:

Files belonging to the package live in /spkg and a link to that file is made in the system directory tree.
Files provided by the package that become the property of the user (mainly files in /etc) live in the system directory tree.

The linking of files back to the installation is inspired by GoboLinux and has advantages and disadvantages.
The main use that spkg make of it is for tracking orphaned files after a package upgrade/uninstall.
It is also useful for seeing which package a file belongs to.
The reason behind adding the installation directory at the root of the file system is to keep symlink names as short as possible and so easier to read.

Conflicting changes to user files are managed ina  similar manner to Arch Linux's pacman; when a conflict is detected the new file provided by the package is installed with a prefix, in our case .spkgnew.

# Build Files

The spkg build system is heavily influenced by Arch Linux's makepkg.

Each build requires a directory with the name of the package spec, which is 
<package name>-<package version>-<package release>.  For example spkg-1.0.0-1 

The release number allows changes, such as security patches, to be made without changing the version number.

The build directory holds a single file named SPKGBUILD. Additional files may be included but usually all files will come from the source tarball.

An SPKGBUILD is a bash file that is sourced by the build system.  It takes the following format:

# Package details, for spkg-1.0.0-1 it would be
pkgname=spkg
pkgver=1.0.0
pkgrel=1

# Details of source files and their checksums
# The first file provided is regarded as the main source tarball
# and will be untarred in the ./src directory
# Subsequent files will be copied to the ./src directory
# Files are cached when downloaded and are always looked for in the cache first
# Https urls will still work in a chroot environment before there is a functioning network
# as long as the files have been downloaded into the sources directory
sources=(
        url to source tarballs (https only at the moment)
        other urls or files (absolute or relative path)
        )
md5sums=(
        md5sum of each file
        )

# Optional: defaults to ( '/etc/*' )
# Which files are to be regarded as owned by the user
userfiles+=( other user files )

# Optional: defaults to name of current package, e.g. ( 'spkg' )
# Which packages this package replaces
replaces+=( other package name )

# Functions to build, test and package up the software

build() {
    # pwd is <build directory>/src so cd into untarred source
    cd "$pkgname-$pkgver"

    # configure
    # make
}

check() {
    # make check
}

package() {
    # Install built files into directory provided for us
    # make DESTDIR=$pkgdir install 
}

# Optional functions to run pre/post install and uninstall
# Note: these functions will be copied out of this file to be called when required
#       so they cannot rely on any of the variables above

# Called with <new package spec> [<old package specs ...>]
pre_install() {
}

post_install() {
}

# Called with <old package spec> [<new package spec>]
pre_uninstall() {
}

post_uninstall() {
}













