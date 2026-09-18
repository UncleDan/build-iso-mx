#!/bin/bash

THEME_DIR=$(dirname $(readlink -f $0))
source $THEME_DIR/../theme-functions.sh
start_theme "$@"

mkdir -p /etc/skel/.local/share/applications/
copy_file grub                  /etc/default/
copy_dir desktop-base/          /usr/share/desktop-base/    --create
copy_dir extra/                 /usr/share/fonts/extra      --create
copy_file libuser.conf          /etc/
copy_file modules               /etc/
copy_file timezone              /etc/
copy_file sddm.conf             /etc/
copy_file pc-speaker.conf       /etc/modprobe.d/
copy_file desktop.data          /usr/share/boot-menus/
copy_file desktop.menu          /usr/share/boot-menus/
copy_file 20-thinkpad.conf      /usr/share/X11/xorg.conf.d/
copy_file yad-icon-browser.desktop /etc/skel/.local/share/applications/ --create
copy_file plymouthd.conf        /etc/plymouth/  --create
copy_file ufw.conf              /etc/ufw/       --create
copy_file zramswap.service      /etc/systemd/system/

# LXQt defaults for the live user and for every new account.
copy_dir  skel-config/          /etc/skel/.config/          --create
# Conky ships with Hidden=true: re-enable with conky-toggle-mx, with MX Tweak,
# or by ticking Conky in LXQt Session Settings > Autostart.
copy_file conky.desktop         /etc/skel/.config/autostart/ --create
copy_file lxqt-labwc.desktop    /usr/share/wayland-sessions/ --create
copy_file run-if-x11            /usr/local/bin/ --create
chmod 0755 "${PREFIX%/}/usr/local/bin/run-if-x11"
chmod 0755 "${PREFIX%/}/etc/skel/.config/labwc/autostart"

#---------------------------------------------------------------------------
# Resolve the themes that actually exist in this build instead of guessing.
#---------------------------------------------------------------------------
ROOT="${PREFIX%/}"
SKEL="$ROOT/etc/skel/.config"

# Widget style: KDE Breeze if this build ships it, Fusion otherwise.
if ls "$ROOT"/usr/lib/*/qt6/plugins/styles/breeze*.so >/dev/null 2>&1; then
    style=Breeze
else
    style=Fusion
fi
sed -i "s/^style=.*/style=$style/"        "$SKEL/lxqt/lxqt.conf"
sed -i "s/^widgetStyle=.*/widgetStyle=$style/" "$SKEL/kdeglobals"
echo "theme.sh: Qt widget style set to $style"

# Icon theme: KDE first, MX Papirus as fallback. Written to both the LXQt
# config and kdeglobals so KF6 applications agree with the panel.
for i in breeze-dark breeze Papirus-mxblue Papirus-Dark Papirus; do
    if [ -d "$ROOT/usr/share/icons/$i" ]; then
        sed -i "s/^icon_theme=.*/icon_theme=$i/" "$SKEL/lxqt/lxqt.conf"
        sed -i "s/^Theme=.*/Theme=$i/"           "$SKEL/kdeglobals"
        echo "theme.sh: icon theme set to $i"
        break
    fi
done

# Colour scheme: a KDE .colors file IS a kdeglobals fragment, so merge it in.
# Without this, ColorScheme= alone would leave Breeze in its light variant.
for cs in BreezeDark Breeze; do
    f="$ROOT/usr/share/color-schemes/$cs.colors"
    [ -f "$f" ] || continue
    tmp=$(mktemp)
    grep -v '^\[General\]' "$f" > "$tmp"
    cat "$SKEL/kdeglobals" >> "$tmp"
    sed -i "s/^ColorScheme=.*/ColorScheme=$cs/" "$tmp"
    mv "$tmp" "$SKEL/kdeglobals"
    echo "theme.sh: colour scheme merged from $cs.colors"
    break
done

# Window decorations for Openbox (X11) and labwc (Wayland). Both read
# Openbox-style themes from /usr/share/themes.
ob=""
for t in Breeze Arc-Dark Adapta-Nokto Clearlooks Onyx; do
    [ -d "$ROOT/usr/share/themes/$t/openbox-3" ] && ob="$t" && break
done
if [ -n "$ob" ]; then
    sed -i "s|<name>THEME</name>|<name>$ob</name>|" \
        "$SKEL/openbox/lxqt-rc.xml" "$SKEL/labwc/rc.xml"
    echo "theme.sh: window decoration theme set to $ob"
else
    # Drop only the <theme> block from labwc's rc.xml: the rest of the file
    # carries the screen-lock keybinding and must survive.
    rm -f "$SKEL/openbox/lxqt-rc.xml"
    sed -i '/<theme>/,/<\/theme>/d' "$SKEL/labwc/rc.xml"
    echo "theme.sh: no Openbox-style theme found, using built-in defaults"
fi

# Main menu icon: use something that actually exists in this build, or drop
# the key so lxqt-panel falls back to its own default rather than to nothing.
menuicon=""
for i in /usr/share/pixmaps/mx-logo.png /usr/share/pixmaps/mxlogo.png \
         /usr/share/icons/hicolor/scalable/apps/mx-logo.svg \
         /usr/share/pixmaps/debian-logo.png; do
    [ -f "$ROOT$i" ] && menuicon="$i" && break
done
if [ -z "$menuicon" ]; then
    for i in start-here distributor-logo start-here-kde; do
        ls -d "$ROOT"/usr/share/icons/*/*/*/"$i".* >/dev/null 2>&1 && menuicon="$i" && break
    done
fi
if [ -n "$menuicon" ]; then
    sed -i "s|^icon=MENUICON$|icon=$menuicon|" "$SKEL/lxqt/panel.conf"
    echo "theme.sh: main menu icon set to $menuicon"
else
    sed -i '/^icon=MENUICON$/d' "$SKEL/lxqt/panel.conf"
    echo "theme.sh: no main menu icon found, using the plugin default"
fi

# Desktop launchers (the MX installer icon) must be executable, otherwise
# PCManFM-Qt asks "execute or open?" on every click.
if [ -d "$ROOT/etc/skel/Desktop" ]; then
    chmod 0755 "$ROOT"/etc/skel/Desktop/*.desktop 2>/dev/null
    echo "theme.sh: marked /etc/skel/Desktop launchers executable"
fi

# Desktop wallpaper: reuse whatever MX artwork this build ships.
wp=""
for d in "$ROOT"/usr/share/backgrounds "$ROOT"/usr/share/wallpapers; do
    [ -d "$d" ] || continue
    wp=$(find "$d" -maxdepth 2 -type f \( -iname '*.jpg' -o -iname '*.png' \) \
         -printf '%s %p\n' 2>/dev/null | sort -rn | head -n1 | cut -d' ' -f2-)
    [ -n "$wp" ] && break
done
if [ -n "$wp" ]; then
    sed -i "s|^Wallpaper=.*|Wallpaper=${wp#$ROOT}|" "$SKEL/pcmanfm-qt/lxqt/settings.conf"
    echo "theme.sh: wallpaper set to ${wp#$ROOT}"
fi

exit
