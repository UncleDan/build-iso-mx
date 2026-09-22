#!/bin/bash
# theme.sh by Daniele Lolli (UncleDan) feat. Claude AI - Release 1.1 - 2026-09-22 11-47-17
# Theme for the mxniri flavours: MX 25.2 AHS with the niri Wayland compositor.
# Same system files as the mx (Xfce) theme, minus the Xfce desktop bits, plus
# the niri session: wayland session entry, session helpers and /etc/skel config.

THEME_DIR=$(dirname $(readlink -f $0))
source $THEME_DIR/../theme-functions.sh
start_theme "$@"

mkdir -p /etc/skel/.local/share/applications/

#--- system files, as in the MX Xfce editions ---------------------------------
copy_file grub                     /etc/default/
copy_dir  desktop-base/            /usr/share/desktop-base/    --create
copy_dir  extra/                   /usr/share/fonts/extra      --create
copy_file libuser.conf             /etc/
copy_file modules                  /etc/
copy_file timezone                 /etc/
copy_file lightdm.conf             /etc/lightdm/
copy_file lightdm-gtk-greeter.conf /etc/lightdm/
copy_file pc-speaker.conf          /etc/modprobe.d/
copy_file desktop.data             /usr/share/boot-menus/
copy_file desktop.menu             /usr/share/boot-menus/
copy_file 20-thinkpad.conf         /usr/share/X11/xorg.conf.d/
copy_file plymouthd.conf           /etc/plymouth/  --create
copy_file ufw.conf                 /etc/ufw/       --create
copy_file zramswap.service         /etc/systemd/system/

#--- niri session -------------------------------------------------------------
copy_file niri-mx-session          /usr/local/bin/ --create
copy_file niri-mx-autostart        /usr/local/bin/ --create
copy_file niri-portals.conf        /etc/xdg/xdg-desktop-portal/ --create
copy_dir  skel-config/             /etc/skel/.config --create

# The session entry shipped by the niri package runs niri-session, which needs
# a systemd user manager. Divert it and install one that also works on
# sysvinit, where the session is started with dbus-run-session niri --session.
session=/usr/share/wayland-sessions/niri.desktop
if [ -z "$DRY_RUN" ]; then
    if ! command -v niri >/dev/null 2>&1; then
        error "niri is not installed: run Tools/build-niri-debs.sh before build-iso"
    elif [ -z "$(dpkg-divert --list "$session")" ]; then
        echo_run dpkg-divert --package mxniri-theme --rename \
            --divert "$session.distrib" --add "$session"
    fi
fi
copy_file niri.desktop             /usr/share/wayland-sessions/ --create

# If the waybar package enables waybar.service for every user
# (graphical-session.target), systemd starts a second bar next to the one of
# niri-mx-autostart, which is the only place meant to start waybar.
if [ -z "$DRY_RUN" ] && command -v systemctl >/dev/null 2>&1 \
    && systemctl --global is-enabled waybar.service >/dev/null 2>&1; then
    echo_run systemctl --global disable waybar.service
fi

exit
