# amerge

amerge is a small update script I wrote for quickly updating the various Gentoo systems I have to maintain. It simply runs through the update process and checks for errors along the way.

#### Steps that amerge performs:
- Emerge Webrsync (emerge-webrsync)
- Layman Sync (layman -S)
- GCC upgrade
  - emerge --oneshot sys-devel/gcc
  - Update configuration (needs rework at some point)
  - emerge --oneshot --usepkg=n sys-devel/libtool
  - revdep-rebuild
- Portage update
- Kernel upgrade
  - emerge sys-kernel/gentoo-sources
  - Update configuration (only works for my specific syslinux install, needs more general rework)
  - Build kernel and install
- Emerge world update (emerge --tree --deep --newuse --update --with-bdeps=y --quiet-build @world)
- Emerge Reverse Rebuild (revdep-rebuild, might be un-needed)
- Emerge Depclean (emerge --depclean)
- Emerge Preserved Rebuild (emerge @preserved-rebuild)

#### A few future features:
- The ability to resume amerge if it caught an error from emerge, will skip sync and kernel updates
- Better kernel updating and configuration updating in general
- CMDARGS to skip GCC auto or Kernel auto
