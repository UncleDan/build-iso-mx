#!/bin/bash
# Creates the LXQt flavour (Input/defaults-lxqt*, Template/mxlxqt*, Themes/mxlxqt)
# by duplicating the KDE one and applying the agreed changes.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."   # repo root, script lives in Tools/

# ---------------------------------------------------------------------------
# Packages dropped from the KDE lists (Plasma itself + everything replaced)
# ---------------------------------------------------------------------------
cat > /tmp/drop.list <<'EOF'
akonadi-contacts-data
ark
baloo6
bluedevil
debconf-kde-helper
digikam
dolphin
drkonqi
ffmpegthumbs
filelight
kaccounts-integration
kaccounts-providers
kactivities-bin
kactivitymanagerd
kamera
kamoso
kate
kate-data
kcalc
kde-config-flatpak
kde-config-gtk-style
kde-config-screenlocker
kde-config-sddm
kde-config-updates
kde-servicemenu-checkhash-installdebs
kde-servicemenu-extract-and-compress
kde-servicemenu-rootactions
kde-spectacle
kde-standard
kde-style-oxygen-qt6
kde-thumbnailer-epub
kdegraphics-thumbnailers
kdenetwork-filesharing
kdeplasma-addons-data
kdialog
kdoctools6
keditbookmarks
kfind
kgamma
kgpg
khelpcenter
kinfocenter
kinit
kio-ldap
kmag
kmahjongg
kmenuedit
kmines
konsole
konsole-kpart
kpackagetool6
krdc
krename
kross
kscreen
ksshaskpass
ksudoku
ktexteditor-data
ktexteditor-katepart
kwalletmanager
kwin-addons
kwin-common
kwin-data
kwin-style-breeze
kwin-wayland
kwin-x11
libbaloowidgets-bin
libreoffice-kf6
libreoffice-plasma
milou
mx-apps-kde
oxygen-icon-theme
oxygen-sounds
pavucontrol
plasma-browser-integration
plasma-dataengines-addons
plasma-desktop
plasma-desktop-data
plasma-discover
plasma-discover-backend-flatpak
plasma-firewall
plasma-framework
plasma-integration
plasma-look-and-feel-theme-mx
plasma-modified-defaults-mx
plasma-nm
plasma-pa
plasma-runners-addons
plasma-systemmonitor
plasma-wallpapers-addons
plasma-widgets-addons
plasma-workspace
plasma5-integration
polkit-kde-agent-1
powerdevil
powerdevil-data
print-manager
qml-module-org-kde-activities
qml-module-org-kde-bluezqt
qml-module-org-kde-draganddrop
qml-module-org-kde-kcm
qml-module-org-kde-kconfig
qml-module-org-kde-kcoreaddons
qml-module-org-kde-kholidays
qml-module-org-kde-kio
qml-module-org-kde-kirigami2
qml-module-org-kde-kquickcontrols
qml-module-org-kde-kquickcontrolsaddons
qml-module-org-kde-kwindowsystem
qml-module-org-kde-newstuff
qml-module-org-kde-purpose
qml-module-org-kde-qqc2desktopstyle
qml-module-org-kde-runnermodel
qml-module-org-kde-solid
smb4k
systemsettings
xdg-desktop-portal-kde
yakuake
EOF

# ---------------------------------------------------------------------------
# LXQt block appended to the package list
# ---------------------------------------------------------------------------
cat > /tmp/add.list <<'EOF'

#--------------------------------------------------------------------------
# LXQt desktop. Only the Plasma *shell* is replaced: the KDE/Qt application
# and theming stack stays, because LXQt is Qt as well and KDE Connect keeps
# KDE Frameworks 6 installed anyway (hence kdeglobals is kept too).
# No GTK application is used as a replacement.
#--------------------------------------------------------------------------
lxqt-core
lxqt-about
lxqt-archiver
lxqt-config
lxqt-globalkeys
lxqt-menu-data
lxqt-notificationd
lxqt-openssh-askpass
lxqt-panel
lxqt-policykit        #replaces polkit-kde-agent-1
lxqt-powermanagement  #replaces powerdevil
lxqt-qtplugin
lxqt-runner
lxqt-session
lxqt-sudo
lxqt-themes
pcmanfm-qt            #replaces dolphin, and draws the desktop
qterminal             #replaces konsole + yakuake (built-in drop-down mode)

#--- window manager (X11) and compositor (Wayland) ------------------------
openbox
obconf-qt
labwc
lxqt-wayland-session  #provides the "LXQt (Wayland)" session + labwc defaults

#--- shell components replaced by LXQt counterparts (all Qt) --------------
nm-tray               #replaces plasma-nm
pavucontrol-qt        #replaces plasma-pa
blueman               #replaces bluedevil: the only GTK exception, because no
                      #standalone Qt bluetooth manager exists. bluedevil is a
                      #Plasma applet + a kded6 module, so outside Plasma it
                      #would cost a resident daemon for a partial UI.
                      #Lubuntu ships blueman for the same reason.
qps                   #replaces plasma-systemmonitor
screengrab            #replaces kde-spectacle
lximage-qt            #replaces gwenview
featherpad            #replaces kate
speedcrunch           #replaces kcalc
qdirstat              #replaces filelight
xdg-desktop-portal-lxqt   #replaces xdg-desktop-portal-kde
mx-apps               #MX tools (Qt), replaces mx-apps-kde; mx-packageinstaller
                      #takes over from plasma-discover

#--- glib VFS used by libfm-qt for mounts, trash and network shares -------
# (a background service, not a GTK application; the KDE apps keep using KIO)
gvfs
gvfs-backends
gvfs-fuse

#--------------------------------------------------------------------------
# Kept from KDE on purpose -- Qt all the way down
#--------------------------------------------------------------------------
# breeze, kde-style-breeze, breeze-icon-theme, breeze-cursor-theme,
#   breeze-gtk-theme      : the look, shared with the SDDM login screen
# frameworkintegration    : makes non-Plasma Qt apps follow kdeglobals
# kio, kio-extras, kded6, kde-cli-tools : KIO for the KDE applications below
# okular, k3b, skanpage, partitionmanager : Qt, and every lighter
#   alternative would have been GTK
# kdeconnect              : no equivalent anywhere; keeps KF6 installed,
#                           which is why kdeglobals must not be purged
# thunderbird             : replaces kmail/kontact
# sddm + sddm-theme-breeze: login screen stays visually identical
EOF

make_pkg_list() {
    local src=$1 dst=$2
    # Strip inline comments before matching, keep the original line otherwise.
    awk 'NR==FNR { drop[$1]=1; next }
         { line=$0; sub(/[[:space:]]*#.*$/, "", line); gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
           if (line != "" && (line in drop)) next
           print }' /tmp/drop.list "$src" > "$dst"
    cat /tmp/add.list >> "$dst"
}

# ---------------------------------------------------------------------------
# Templates
# ---------------------------------------------------------------------------
for pair in "mxkde:mxlxqt" "mxkde-sysv:mxlxqt-sysv"; do
    src=Template/${pair%%:*} dst=Template/${pair##*:}
    rm -rf "$dst"; cp -a "$src" "$dst"
    make_pkg_list "$src/package.list" "$dst/package.list"
    echo "LXQt" > "$dst/default-desktop"
    # desktop-defaults-mx-kde must never sneak in: there is no LXQt counterpart.
    sed -i 's|^desktop-defaults-mx-kde$|desktop-defaults-mx-kde   #KDE-only defaults: must not be installed|' \
        "$dst/pesky-package.list"
    # Report drop entries that no longer exist upstream: after a master update
    # a renamed or removed package would otherwise be dropped silently.
    while read -r d; do
        [ -z "$d" ] && continue
        grep -qE "^$d([[:space:]]|#|$)" "$src/package.list" || echo "    note: '$d' not in $src/package.list (upstream change?)"
    done < /tmp/drop.list
    echo "  created $dst ($(grep -cve '^\s*#' -e '^\s*$' "$dst/package.list") packages)"
done

# ---------------------------------------------------------------------------
# Input defaults
# ---------------------------------------------------------------------------
for pair in "kde:lxqt" "kde-sysv:lxqt-sysv"; do
    src=Input/defaults-${pair%%:*} dst=Input/defaults-${pair##*:}
    sed -e 's|^DEFAULTDESKTOP="KDE"|DEFAULTDESKTOP="LXQt"|' \
        -e 's|^DEFAULTDESKTOP="KDE_sysvinit"|DEFAULTDESKTOP="LXQt_sysvinit"|' \
        -e 's|^ISO_FLAV="mxkde"|ISO_FLAV="mxlxqt"|' \
        -e 's|^ISO_FLAV="mxkde-sysv"|ISO_FLAV="mxlxqt-sysv"|' \
        -e 's|^THEME="mxkde"|THEME="mxlxqt"|' \
        -e 's|^X_TERM_EMULATOR="/usr/bin/konsole"|X_TERM_EMULATOR="/usr/bin/qterminal"|' \
        "$src" > "$dst"
    echo "  created $dst"
done

# ---------------------------------------------------------------------------
# Theme
# ---------------------------------------------------------------------------
rm -rf Themes/mxlxqt
cp -a Themes/mxkde Themes/mxlxqt

# Conky: disabled by default, re-enabled by deleting the line, by
# conky-toggle-mx, or by ticking the box in LXQt Session Settings.
sed -i 's|^Hidden=false$|Hidden=true|' Themes/mxlxqt/misc/conky.desktop

# SDDM: same theme, same cursor, only the autologin session changes.
sed -i 's|^Session=plasma.desktop$|Session=lxqt.desktop|' Themes/mxlxqt/misc/sddm.conf

mkdir -p Themes/mxlxqt/skel-config/{lxqt,openbox,labwc,autostart,pcmanfm-qt/lxqt}

cat > Themes/mxlxqt/skel-config/lxqt/session.conf <<'EOF'
[General]
__userfile__=true
# X11 session -> Openbox ; Wayland session -> labwc.
# Both live in this one file: there is no separate wayland-session.conf.
window_manager=openbox
compositor=labwc
leave_confirmation=true

[Mouse]
cursor_theme=breeze_cursors
cursor_size=24
EOF

cat > Themes/mxlxqt/skel-config/lxqt/lxqt.conf <<'EOF'
[General]
__userfile__=true
# KDE's own Breeze stack: LXQt is Qt, so the Plasma theming keeps working.
icon_theme=breeze-dark
theme=kde-plasma
single_click_activate=false

[Qt]
style=Breeze
EOF

# Minimal kdeglobals for the live user: KDE Connect and every other KF6
# application reads it. theme.sh merges the Breeze colour scheme into it at
# build time.
cat > Themes/mxlxqt/skel-config/kdeglobals <<'EOF'
[General]
ColorScheme=BreezeDark

[Icons]
Theme=breeze-dark

[KDE]
widgetStyle=Breeze
EOF

# <name>THEME</name> is substituted at build time with a theme that exists.
cat > Themes/mxlxqt/skel-config/openbox/lxqt-rc.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <theme>
    <name>THEME</name>
    <titleLayout>NLIMC</titleLayout>
    <keepBorder>yes</keepBorder>
  </theme>
</openbox_config>
EOF

cat > Themes/mxlxqt/skel-config/labwc/rc.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<labwc_config>
  <theme>
    <name>THEME</name>
    <cornerRadius>4</cornerRadius>
  </theme>
</labwc_config>
EOF

cat > Themes/mxlxqt/skel-config/pcmanfm-qt/lxqt/settings.conf <<'EOF'
[Desktop]
Wallpaper=
WallpaperMode=stretch
BgColor=#000000
ShowWmMenu=false
EOF

# Outside Plasma there is no KDE Connect applet: the standalone indicator
# has to be started with the session.
cat > Themes/mxlxqt/skel-config/autostart/kdeconnect-indicator.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=KDE Connect Indicator
Exec=kdeconnect-indicator
Icon=kdeconnect
Terminal=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

cat > Themes/mxlxqt/skel-config/autostart/nm-tray.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Network Manager Tray
Exec=nm-tray
Icon=network-workgroup
Terminal=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF

cat > Themes/mxlxqt/theme.sh <<'THEME'
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
    rm -f "$SKEL/openbox/lxqt-rc.xml" "$SKEL/labwc/rc.xml"
    echo "theme.sh: no Openbox-style theme found, using built-in defaults"
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
THEME
chmod +x Themes/mxlxqt/theme.sh

echo "  created Themes/mxlxqt"
