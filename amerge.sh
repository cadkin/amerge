#!/bin/bash

SECONDS=0
LAYMAN_PATH=/usr/bin/layman
REVDEP_PATH=/usr/bin/revdep-rebuild

printf "\033[1;34m\nStarting automerge on %s.\n\033[0m" "$(date)"

# Fetching the latest repos.
printf "\033[1;31m\n- Portage Sync -----------------------------------------\n\n\033[0m"
emerge-webrsync
if (($? != 0)); then
    printf "Caught error from emerge-webrsync.\n" $?
    exit -1
fi
if [ -e "$LAYMAN_PATH" ]; then
    printf "\033[1;31m\n- Layman Sync ------------------------------------------\n\033[0m"
    layman -S
    if (($? != 0)); then
        printf "Caught error from layman.\n" $?
        exit -1
    fi
else
    printf "\n"
fi

# Read the news.
#eselect news read

# Pretend a merge to catch any errors.
#printf "\033[1;31m- Emerge Pretend ---------------------------------------\n\033[0m"
#emerge --pretend --deep --newuse --update @world
#if (($? != 0)); then
#    printf "Caught error from emerge phase.\n" $?
#    exit -2
#fi

# If everything looks fine, continue with merging.
printf "\033[1;31m\n- Emerge Merge -----------------------------------------\n\n\033[0m"
emerge --tree --deep --newuse --update --quiet-build @world
if (($? != 0)); then
    printf "Caught error from emerge phase.\n"
    exit -2
fi

# Rebuild any broken libraries.
printf "\033[1;31m\n- Reverse Dependency Rebuild ---------------------------\n\n\033[0m"
if [ -e "$REVDEP_PATH" ]; then
    revdep-rebuild
    if (($? != 0)); then
        printf "Caught error from revdep-rebuild.\n"
        exit -3
    fi
else
    printf "Please install 'gentoolkit' for reverse dependency rebuild support. This is recommended.\n"
fi

# Update the configuration files.
#etc-update --automode 9

# Clean up the system.
printf "\033[1;31m\n- Emerge Dependency Clean ------------------------------\n\033[0m"
emerge --depclean
if (($? != 0)); then
    printf "Caught error during depclean.\n" $?
    exit -4
fi

# Rebuild any packages still using older libraries.
printf "\033[1;31m\n- Emerge Preserved Rebuild -----------------------------\n\n\033[0m"
emerge @preserved-rebuild

# Update the kernel.
printf "\033[1;31m\n- Kernel Upgrade ---------------------------------------\n\033[0m"
eselect kernel set 1
# Determining kernel versions.
CKERN=$(uname -r)
NKERN=$(eselect kernel show|grep "/usr/src/linux-" |sed -e 's/  \/usr\/src\/linux-//g')

if [ "$CKERN" == "$NKERN" ]; then
    printf "\nNo new kernel, skipping auto-upgrade.\n"
else
    printf "\033[1;34m\nUpdating the configuration for the new kernel.\n\033[0m"
    cd /usr/src/linux
    cp /usr/src/linux-${CKERN}/.config /usr/src/linux/.config
    make olddefconfig

    printf "\033[1;34m\nBuilding the new kernel.\n\033[0m"
    cat /usr/src/linux/.config | grep --quiet MODULES=y
    if (($? == 0)); then
        # Make and install the kernel.
        make -j3 && make modules_install && make install
    else
        # Make and install the kernel (no modules).
        make -j3 && make install
    fi

    # Update extlinux config and store old kernel.
    printf "\033[1;34m\nUpdating bootloader configuration.\n\033[0m"
    cd /boot/
    sed -i "s/$CKERN/$NKERN/g" /boot/extlinux/extlinux.conf
    mkdir /boot/old_kernel/$CKERN/
    mv *$CKERN /boot/old_kernel/$CKERN/
    rm /boot/*.old
fi

printf "\033[1;31m\n--------------------------------------------------------\n\033[0m"
DURATION=$SECONDS
printf "\033[1;34m\nFinished automerge in %d minutes and %d seconds.\n\n\033[0m" $(($DURATION / 60)) $(($DURATION % 60))

exit 0