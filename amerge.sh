#!/bin/bash

# A (hopefully) comprehensive script to perform upgrades on a Gentoo system.
# Last update: 08/14/18

KJOBS=4
LAYMAN_PATH=/usr/bin/layman
REVDEP_PATH=/usr/bin/revdep-rebuild
GCC_AUTO=true

SECONDS=0
# Check if any package will be updated prior to world update.
function will_pkg_be_updated {
    VER_INS="$(portageq best_version / "$1")"
    VER_AVL="$(portageq best_visible / "$1")"

    if [ "$VER_INS" == "$VER_AVL" ]; then
        RESULT=false
    else
        RESULT=true
    fi
}

# Print out a divider of width 60 with a label.
function printdiv {
    printf "\033[1;31m\n-"

    if [ -z "$1" ]; then
        printf -- "-----------------------------------------------------------\n\033[0m"
        return
    else
        SIZE=${#1}
        REMAIN=$((57-$SIZE))
        
        if [ $REMAIN -lt 0 ]; then
            printf " PRINTDIV_ERR: String must be no greater than 56 characters. -\n\033[0m"
            return
        fi

        printf " " 
        printf "%s " $1
        while [ $REMAIN -gt 0 ]; do 
            printf "-"
            let REMAIN=REMAIN-1
        done
        printf "\n\033[0m"
    fi
}

function printerr {
    printdiv ""
    printf "%s " $1
    printf "\n"
    exit 128
}

printf "\033[1;34m\nStarting automerge on %s.\n\033[0m" "$(date)"

# Fetching the latest repos.
printdiv "Portage Sync"
emerge-webrsync
if (($? != 0)); then printerr "Caught error from emerge-webrsync during sync."; fi

if [ -e "$LAYMAN_PATH" ]; then
    printdiv "Layman Sync"
    layman -S
    if (($? != 0)); then printerr "Caught error from layman during sync."; fi
else
    printf "\n"
fi

# Check if gcc is going to be upgraded. If it is, check if the user wants to automatically handle this and act accordingly.
will_pkg_be_updated "sys-devel/gcc"
if ( $RESULT == true ); then
    if ( $GCC_AUTO == false ); then
        printdiv ""
        printf "\033[1;34m\nGCC upgrade detected! Please perform this manually or change GCC_AUTO to true.\n"
        exit 128
    fi

    printdiv "GCC Upgrade: Emerge"
    printf "\nGCC upgrade detected! Performing auto-upgrade (set GCC_AUTO to false to disable this function).\n\033[0m"
    emerge --oneshot sys-devel/gcc
    if (($? != 0)); then printerr "Caught error from emerge during gcc upgrade."; fi

    printdiv "GCC Upgrade: Config"
    gcc-config 2
    source /etc/profile

    printdiv "GCC Upgrade: sys-devel/libtool"
    emerge --oneshot --usepkg=n sys-devel/libtool
    if (($? != 0)); then printerr "Caught error from emerge during libtool upgrade."; fi

    printdiv "GCC Upgrade: Reverse Dependency Rebuild"
    revdep-rebuild
    if (($? != 0)); then printerr "Caught error from revdep-rebuild during gcc upgrade."; fi
fi

# Set a flag for kernel upgrades later.
will_pkg_be_updated "sys-kernel/gentoo-sources"
if ( $RESULT == true); then
    KUPGRADE=true
else
    KUPGRADE=false
fi

# Update portage first.
will_pkg_be_updated "sys-apps/portage"
if ($RESULT == true); then
    printdiv "Portage Upgrade"
    emerge --tree --quiet-build sys-apps/portage
    if (($? != 0)); then printerr "Caught error from emerge during portage upgrade."; fi
fi
    
# If everything looks fine, continue with merging.
printdiv "Emerge Merge"
emerge --tree --deep --newuse --update --quiet-build @world
if (($? != 0)); then printerr "Caught error from emerge during world update."; fi

# Rebuild any broken libraries.
printdiv "Reverse Dependency Rebuild"
if [ -e "$REVDEP_PATH" ]; then
    revdep-rebuild
    if (($? != 0)); then printerr "Caught error from revdep-rebuild during world update."; fi
else
    printf "Please install 'gentoolkit' for reverse dependency rebuild support. This is recommended.\n"
fi

# Clean up the system.
printdiv "Emerge Dependency Clean"
emerge --depclean
if (($? != 0)); then printerr "Caught error from emerge during depclean."; fi

# Rebuild any packages still using older libraries.
printdiv "Emerge Preserved Rebuild"
emerge @preserved-rebuild
if (($? != 0)); then printerr "Caught error from emerge during preserved rebuild."; fi

# Update the kernel.
printdiv "Kernel Upgrade"
if ( $KUPGRADE == true ); then
    eselect kernel set 1
    # Determining kernel versions.
    CKERN=$(uname -r)
    NKERN=$(eselect kernel show|grep "/usr/src/linux-" |sed -e 's/  \/usr\/src\/linux-//g')
    
    printf "\033[1;34m\nUpdating the configuration for the new kernel.\n\033[0m"
    cd /usr/src/linux
    cp /usr/src/linux-${CKERN}/.config /usr/src/linux/.config
    make olddefconfig
    
    printf "\033[1;34m\nBuilding the new kernel.\n\033[0m"
    cat /usr/src/linux/.config | grep --quiet MODULES=y
    if (($? == 0)); then
        # Make and install the kernel.
        make -j${KJOBS} && make modules_install && make install
    else
        # Make and install the kernel (no modules).
        make -j${KJOBS} && make install
    fi
    
    # Update extlinux config and store old kernel.
    printf "\033[1;34m\nUpdating bootloader configuration.\n\033[0m"
    cd /boot/
    sed -i "s/$CKERN/$NKERN/g" /boot/extlinux/extlinux.conf
    mkdir /boot/old_kernel/$CKERN/
    mv *$CKERN /boot/old_kernel/$CKERN/
    rm /boot/*.old
else 
    printf "\nNo new kernel, skipping auto-upgrade.\n"
fi

printdiv ""
DURATION=$SECONDS
printf "\033[1;34m\nFinished automerge in %d minutes and %d seconds.\n\n\033[0m" $(($DURATION / 60)) $(($DURATION % 60))

exit 0
