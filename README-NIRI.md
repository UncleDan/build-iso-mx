# MX niri flavour (mxniri)

MX 25 AHS with [niri](https://github.com/niri-wm/niri), a scrollable-tiling
Wayland compositor, in place of the Xfce desktop. **The applications are the
same as the MX Xfce AHS edition**: only the Xfce desktop itself is replaced.

| Flavour | Defaults file | Init |
|---|---|---|
| `mxniri` | `Input/defaults-Niri-ahs` | systemd, siduction kernel 7.x |
| `mxniri-sysv` | `Input/defaults-Niri-ahs-sysv` | sysvinit, siduction kernel 6.x |

Both use the `mxniri` theme and the same repositories (Debian trixie, MX main
and MX AHS) as the Xfce AHS flavours. Nothing outside `Input/defaults-Niri-*`,
`Template/mxniri*`, `Themes/mxniri`, `Tools/build-niri-debs.sh` and this file
is touched: `build-iso` and the existing flavours are untouched.

## Build

niri and xwayland-satellite are in no Debian or MX repository, so they are
compiled into `.deb` packages first, on the trixie build host:

```bash
./Tools/build-niri-debs.sh      # -> Deb/mxniri/ and Deb/mxniri-sysv/
sudo ./build-iso --user-default defaults-Niri-ahs
sudo ./build-iso --user-default defaults-Niri-ahs-sysv
```

The script uses trixie's own Rust (1.85, the minimum both projects require)
with `--locked`, builds with `cargo`, packages with `dpkg-deb` and computes
the dependencies with `dpkg-shlibdeps`. Versions are pinned by `NIRI_VERSION`
(default `v26.04`) and `XWS_VERSION` (default `v0.8.2`); set `CARGO` to use a
rustup toolchain instead. build-iso installs whatever it finds in
`Deb/<flavour>/` inside the chroot in stage 4, part 10, letting apt pull the
dependencies.

## What replaces what

Removed, 42 packages, all of them Xfce desktop components:
`xfce4-panel` and every panel plugin, `xfce4-session`, `xfce4-settings`,
`xfwm4`, `xfdesktop4`, `xfce4-appfinder`, `xfce4-notifyd`,
`xfce4-power-manager`, `xfce4-screensaver`, `xfce4-screenshooter`,
`xfce4-clipman`, `xfce-superkey-mx`, `desktop-defaults-mx-xfce`,
`piranha2-xfwm4-theme`, `xfce-modified-default-background`,
`xdg-desktop-portal-xapp`, `gxkb`.

| Xfce | mxniri |
|---|---|
| xfwm4 + xfdesktop | niri + swaybg |
| xfce4-panel, whisker menu | waybar, fuzzel (Mod+D) |
| xfce4-notifyd | mako |
| xfce4-screensaver | swaylock (Super+Alt+L) + swayidle |
| xfce4-power-manager | brightnessctl + tlp (already there) |
| xfce4-screenshooter | niri built-in screenshots (Print) |
| xfce4-clipman | wl-clipboard |
| xfce4-xkb-plugin, gxkb | `mx-keyboard.kdl`, written from `/etc/default/keyboard` |
| xdg-desktop-portal-xapp | xdg-desktop-portal-gnome + -gtk |
| X11 applications | xwayland-satellite + xwayland |

Everything else stays: Thunar and its plugins, xfce4-terminal (still the
`x-terminal-emulator`, bound to Mod+T), xfce4-taskmanager, xfce4-notes,
xfburn, orage, menulibre, mugshot, LibreOffice, Firefox, Thunderbird, VLC,
MX Tools, MX Installer, LightDM with the MX greeter, network-manager-gnome,
blueman, gnome-keyring, polkit-gnome, Xorg (the greeter still runs on X11).

Conky, `feh`, `magnus` and `onboard` are still installed, as in the Xfce
edition, but they are X11 programs: under niri they run as ordinary windows
through xwayland-satellite. Conky is not started automatically; `mx.kdl` has
a commented line to start it.

## Session

- `/usr/share/wayland-sessions/niri.desktop` from the niri package is diverted
  with `dpkg-divert` and replaced by one running `/usr/local/bin/niri-mx-session`:
  `niri-session` when systemd is PID 1, `dbus-run-session niri --session`
  otherwise. This is what makes the sysvinit flavour work.
- LightDM: `user-session=niri`, `autologin-session=niri`; the greeter is
  unchanged.
- `/etc/skel/.config/niri/config.kdl` is the upstream default config of
  niri 26.04 with three changes: `spawn-at-startup "niri-mx-autostart"`,
  Mod+T opens xfce4-terminal, and `mx.kdl` plus `mx-keyboard.kdl` are
  included at the end.
- `niri-mx-autostart` starts waybar, mako, the polkit agent, `nm-applet
  --indicator` (the tray of waybar only shows StatusNotifierItem icons),
  swaybg with the MX wallpaper and swayidle — no automatic lock in the live
  session. It also writes `mx-keyboard.kdl` from `/etc/default/keyboard`, so
  the layout chosen in the live boot menu or by the installer is applied, and
  on sysvinit it runs XDG autostart with `dex` (with systemd that is
  `xdg-desktop-autostart.target`).
- `/etc/xdg/xdg-desktop-portal/niri-portals.conf` sends file chooser dialogs
  to the GTK portal, so xdg-desktop-portal-gnome does not require nautilus.

## Keys

`Mod` is the Super key. Mod+T terminal, Mod+D launcher, Mod+E Thunar,
Mod+Shift+D MX Tools, Mod+Shift+T task manager, Super+Alt+L lock,
Mod+Shift+Slash the full list, Mod+Shift+E quit the session.

## Files

```
Input/defaults-Niri-ahs, defaults-Niri-ahs-sysv
Template/mxniri/, Template/mxniri-sysv/       package.list and apt sources
Themes/mxniri/theme.sh                        theme
Themes/mxniri/misc/                           niri-mx-session, niri-mx-autostart,
                                              niri.desktop, niri-portals.conf,
                                              lightdm.conf, MX system files
Themes/mxniri/skel-config/                    niri, waybar and autostart skel
Tools/build-niri-debs.sh                      builds the two .deb packages
```

## Untested

The flavour has not been built into an ISO yet. Worth checking first: that
LightDM starts the Wayland session, the sysvinit variant (portals without
systemd are the fragile part), and that every added package name exists in
trixie — build-iso reports missing ones at the end of stage 4, part 8.
