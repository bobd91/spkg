Simple Package Manager

Bootstrap

Download the latest spkg tar file to the source file dirctory, check the md5sum, untar and cd into the spkg directory

If spkg is being installed pre-chroot

./configure --prefix=$LFS/tools --exec-prefix=$LFS/tools/bin --with-sysroot=$LFS
make install

If installed on a chrooted (or finished) system

./configure
make install

See configure --help for additional options.

Bash Completion

Bash completion is available, for instructions see BASH_COMPLETION.md

Install

spkg should now be in the PATH so use it to install itself, this also provides a sanity check that it works.

# List build directories, if prefixed by a space then they have not been built
spkg list -d
  spkg-1.0.0-1

# Build the spkg package
spkg build spkg-1.0.0-1

# List packages, if prefixed by a space then they have not been installed
spkg list
  spkg-1.0.0-1

spkg install spkg

# List packages, if prefixed by an asterisk then they have been installed
spkg list
* spkg-1.0.0-1

For those who are installing pre-chroot the newly installed version will not be usable until chrooted, 
the bootsrap version can be used until then.



