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
k3b
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
kde-cli-tools
kde-cli-tools-data
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
kded6
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
partitionmanager
okular
okular-extra-backends
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
skanpage
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
#lxqt-wayland-session  NOT IN TRIXIE (forky/sid only). The Wayland session is
#                      provided by Themes/mxlxqt instead: a wayland-sessions
#                      desktop entry plus labwc autostart/environment files.

#--- shell components replaced by LXQt counterparts (all Qt) --------------
nm-tray               #replaces plasma-nm
network-manager-gnome #GTK, but it owns nm-connection-editor, which nm-tray
                      #calls for VPN/static IP/802.1X: nm-tray has no editor
                      #of its own. Its nm-applet tray icon is disabled in
                      #/etc/skel to avoid two icons. Same choice as Lubuntu.
pavucontrol-qt        #replaces plasma-pa
blueman               #replaces bluedevil: the only GTK exception, because no
                      #standalone Qt bluetooth manager exists. bluedevil is a
                      #Plasma applet + a kded6 module, so outside Plasma it
                      #would cost a resident daemon for a partial UI.
                      #Lubuntu ships blueman for the same reason.
qps                   #replaces plasma-systemmonitor
screengrab            #replaces kde-spectacle
lximage-qt            #replaces gwenview
qpdfview              #replaces okular: Qt5, but far lighter than okular+KIO
skanlite              #replaces skanpage: same KSane backend, plain Qt widgets
                      #instead of the whole Kirigami/QML stack
featherpad            #replaces kate
qdirstat              #replaces filelight
qalculate-qt          #replaces kcalc: Qt6 and no KF6 dependency at all,
                      #and a far more capable calculator. Lubuntu's choice
xfburn                #replaces k3b: GTK, but it is what MX itself ships in
                      #the Xfce and Fluxbox editions, so it is tested on this
                      #distro and far lighter than k3b
gparted               #replaces partitionmanager: same reasoning, and it is
                      #the partition editor of the MX Xfce edition
xscreensaver          #screen lock on X11: kscreenlocker went away with
xscreensaver-data     #plasma-workspace, and LXQt has no locker of its own
swaylock              #screen lock on Wayland (xscreensaver cannot lock there)
picom                 #compositor for Openbox: shadows, transparency, no
                      #tearing. Not needed under labwc, which composites
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
# kio, kio-extras          : KIO for the KDE applications below
# (k3b and partitionmanager were dropped for xfburn and gparted: the
#   two GTK tools MX itself ships in its other editions)
# NOT kept: kded6 and kde-cli-tools were dropped from the explicit list.
#   If some dependency really needs them, apt pulls them back in by
#   itself - which is exactly the point of not listing them
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
    cat >> "$dst" <<'EOF'

# Timestamp appended to the ISO file name (and therefore to its .sha256,
# .zsync and .sig). Comment out for the plain MX-<ver>_LXQt_x64.iso name.
# Evaluated once when this file is sourced, so every file of one build agrees.
ISO_TIMESTAMP="$(date +%Y%m%d-%H%M)"
EOF
    echo "  created $dst"
done

# ---------------------------------------------------------------------------
# build-iso patch: optional timestamp in the ISO file name
# ---------------------------------------------------------------------------
# Applied to the two places where iso_file is composed. Idempotent, so
# re-running this script after a master update re-applies it cleanly.
# The timestamp deliberately does NOT go into DISTRO_VERSION: that variable
# also names Output/<name> and Remaster/work/<name>, so a value that changes
# every run would orphan a multi-GB work directory per build and break
# resuming with -from.
if grep -q 'ISO_TIMESTAMP' build-iso; then
    echo "  build-iso already patched for ISO_TIMESTAMP"
else
    sed -i 's|^\( *\)local iso_file=\$full_distro_name\.iso$|\1local iso_file=$full_distro_name${ISO_TIMESTAMP:+_$ISO_TIMESTAMP}.iso|' build-iso
    n=$(grep -c 'ISO_TIMESTAMP' build-iso)
    [ "$n" -eq 2 ] || { echo "  ERROR: patched $n/2 occurrences in build-iso" >&2; exit 1; }
    echo "  patched build-iso for ISO_TIMESTAMP (2 occurrences)"
fi

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
# Read by startlxqtwayland from lxqt-wayland-session, which is not in trixie
# yet (forky/sid only). Harmless now, correct as soon as it lands.
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
  <keyboard>
    <!-- <default/> keeps labwc's built-in keybindings alongside this one. -->
    <default />
    <keybind key="W-l">
      <action name="Execute" command="swaylock -f -c 1c1c1c" />
    </keybind>
  </keyboard>
</labwc_config>
EOF

# Wayland session entry, replacing the one lxqt-wayland-session would install.
# Upstream requires the compositor autostart to run "lxqt-session && <exit>",
# so that closing the LXQt session also stops labwc.
cat > Themes/mxlxqt/misc/lxqt-labwc.desktop <<'EOF'
[Desktop Entry]
Name=LXQt (Wayland)
Comment=LXQt session on Wayland, with labwc as compositor
Exec=labwc
TryExec=labwc
Type=Application
DesktopNames=LXQt
Keywords=wayland;labwc;lxqt;
EOF

cat > Themes/mxlxqt/skel-config/labwc/autostart <<'EOF'
#!/bin/sh
# Starting point of the LXQt Wayland session: lxqt-session runs the desktop,
# and labwc exits as soon as the session ends.
lxqt-session && labwc --exit
EOF

cat > Themes/mxlxqt/skel-config/labwc/environment <<'EOF'
XDG_CURRENT_DESKTOP=LXQt
XDG_SESSION_DESKTOP=LXQt
QT_QPA_PLATFORM=wayland;xcb
QT_WAYLAND_DISABLE_WINDOWDECORATION=1
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
# X11-only autostart helper: picom and xscreensaver must not run under labwc.
# A .desktop file cannot test the session itself (Exec quoting makes it
# fragile), so the test lives in this one-line wrapper.
cat > Themes/mxlxqt/misc/run-if-x11 <<'EOF'
#!/bin/sh
# Run the given command only in an X11 session.
[ -n "$WAYLAND_DISPLAY" ] && exit 0
exec "$@"
EOF

cat > Themes/mxlxqt/skel-config/autostart/picom.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Picom (X11 compositor)
Exec=run-if-x11 picom
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

cat > Themes/mxlxqt/skel-config/autostart/xscreensaver.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=XScreenSaver (X11 screen lock)
Exec=run-if-x11 xscreensaver -no-splash
Terminal=false
X-GNOME-Autostart-enabled=true
EOF

# network-manager-gnome ships its own tray applet; nm-tray is the Qt one we
# want, so the GTK icon is hidden to avoid two identical tray icons.
cat > Themes/mxlxqt/skel-config/autostart/nm-applet.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Network (GTK applet, disabled)
Exec=nm-applet
Terminal=false
Hidden=true
EOF

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
