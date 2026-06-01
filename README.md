# spkg
Simple Package Manager

Note: this is pre-release software, it may change before release and the documentation is incomplete

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

spkg can be used from the start of a new system build allowing most installed software to be managed, 
though it can be installed later and used for new and upgraded packages.
Comprised of a Bash script and a config file it has no dependencies beyond those specified for a LFS build.

The first pass of the coreutils and gcc cross compiler should be installed as per the LFS Book.  
Everything else can be built and installed using spkg.

For those building a new LFS system a companion program, lfs2spkg, can be used to produce spkg build
files from the LFS Book source.  This does not do everything for you but does avoid the majority of typing in build instructions.

## Installation

Installing a package manager when you don't have a package manager poses some problems.

In our case a temporary version is installed which is then used to install the final version.
In a pre-chroot environment the temporary version is installed in $LFS/tools/bin and is used
until the chroot environment is entered.

See INSTALL.md for installation instructions

## The File System

The following directories are used by spkg:

/var/lib/spkg/build         Package build directories
/var/lib/spkg/pkg           Tar.gz files of built packages

/var/lib/spkg/old/build     Package build directories for packages that have been uninstalled
/var/lib/spkg/old/pkg       Package tar.gz files for packages that have been uninstalled

/var/log/spkg               spkg log files

/spkg                       installed package files

Installed package files live in /spkg and a link to that file is made in the system directory tree.
Files that become the property of the user (mainly files in /etc) live in the system directory tree.

The linking of files back to the package is inspired by GoboLinux and has advantages and disadvantages.
Spkg uses it for locating orphaned files after a package upgrade/uninstall.
It is also useful for seeing which package a file belongs to.

Conflicting changes to user files are managed in a similar manner to Arch Linux's pacman; when a conflict is detected the new file provided by the package is installed with a prefix, in our case .spkgnew.

Spkg does not have a package database but rather uses the file system.  You may move files in
and out of the /var/lib/spkg/..  directories as you see fit.  The package manager
does not remove files from the ./old directories so over time they may get rather large.  Removing
unwanted files is an excercise for the reader.

## The Package Build Process

The spkg build system is influenced by Arch Linux's makepkg.  The build instructions are held
in a single file, SPKGBUILD.  See SPKGBUILD.md for information on the content of this file.

A package spec is a hyphen delimited triplet of package name, package version and package release number as name-version-release.  
(The package release is used to create a new package without version number change, used for small
changes such as applying security patches.)

The spkg/build directory contains directories named for each package spec. Each package build directory
must contain a SPKGBUILD file and may contain other files required for the build.

A brief outline of the build process is as follows:
 - source files are copied to ./src and md5sums checked
 - the first source file is untarred
 - the build() function is called
 - the package() function is called
 - the content of ./pkg/<package spec> is tarred/gzipped into spkg/pkg/
 - the ./src and ./pkg directories are removed

It is the aim of the build process to NOT write any files to the main file system tree. For this
reason is is good practice to run the build as a non-root user.  
When building pre-chroot it is suggested that the $LFS/ file system tree is owned by root.

### Building A Package

spkg build [options] <package spec>

Will build the source package and create an spkg package ready for installation.

By default package tests/checks are not performed during the build. Running the checks can be
enabled by providng the -c option.

Pproviding the -b option will halt the build after the software has been built and locally installed but before creating the
spkg package.

Passing the -p option will create an spkg package from a previously halted build -b.


## The Package Installation Process













