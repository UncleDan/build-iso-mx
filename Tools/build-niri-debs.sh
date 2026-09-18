#!/bin/bash
#==============================================================================
# build-niri-debs.sh
#
# Build .deb packages of niri and xwayland-satellite for Debian 13 "trixie"
# (neither is in the Debian or MX repositories) and drop them where build-iso
# picks them up for the mxniri flavours:
#
#     Deb/mxniri/        Deb/mxniri-sysv/
#
# build-iso installs every .deb found there inside the chroot (stage 4,
# part 10 "Install latest antiX debs"), resolving dependencies with apt.
#
# Run it on the build host (Debian trixie) from the build-iso-mx directory:
#
#     ./Tools/build-niri-debs.sh                 # pinned versions
#     NIRI_VERSION=v26.04 XWS_VERSION=v0.8.2 ./Tools/build-niri-debs.sh
#
# Rust: trixie ships rustc 1.85, which is exactly the MSRV of both projects,
# so the Debian toolchain is used with --locked. Set CARGO=... to use another
# cargo (for example ~/.cargo/bin/cargo from rustup).
#==============================================================================

set -euo pipefail

NIRI_VERSION=${NIRI_VERSION:-v26.04}
XWS_VERSION=${XWS_VERSION:-v0.8.2}
DEB_REVISION=${DEB_REVISION:-1~mx25}
MAINTAINER=${MAINTAINER:-"MX niri flavour <root@localhost>"}
JOBS=${JOBS:-$(nproc)}

NIRI_REPO=https://github.com/niri-wm/niri.git
XWS_REPO=https://github.com/Supreeeme/xwayland-satellite.git

SCRIPT_DIR=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
TOP_DIR=$(dirname "$SCRIPT_DIR")
WORK_DIR=${WORK_DIR:-$TOP_DIR/niri-build}
OUT_DIRS=("$TOP_DIR/Deb/mxniri" "$TOP_DIR/Deb/mxniri-sysv")
CARGO=${CARGO:-cargo}

# niri pulls smithay from git: the git CLI copes with proxies better than libgit2.
export CARGO_NET_GIT_FETCH_WITH_CLI=${CARGO_NET_GIT_FETCH_WITH_CLI:-true}

BUILD_DEPS=(
    git ca-certificates curl pkg-config gcc clang dpkg-dev fakeroot
    rustc cargo
    libudev-dev libgbm-dev libxkbcommon-dev libegl1-mesa-dev libwayland-dev
    libinput-dev libdbus-1-dev libsystemd-dev libseat-dev libpipewire-0.3-dev
    libpango1.0-dev libdisplay-info-dev
    libxcb1-dev libxcb-cursor-dev
)

say()  { printf '\e[1;36m==> %s\e[0m\n' "$*"; }
die()  { printf '\e[1;31mError: %s\e[0m\n' "$*" >&2; exit 1; }

usage() {
    sed -n '3,24p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
}

[[ ${1:-} == -h || ${1:-} == --help ]] && usage

#------------------------------------------------------------------------------
install_build_deps() {
    local missing=() pkg
    for pkg in "${BUILD_DEPS[@]}"; do
        # A custom CARGO (e.g. rustup) replaces Debian's rustc/cargo.
        [[ $CARGO != cargo && $pkg =~ ^(rustc|cargo)$ ]] && continue
        dpkg-query -W -f '${db:Status-Abbrev}' "$pkg" 2>/dev/null | grep -q '^ii' \
            || missing+=("$pkg")
    done
    (( ${#missing[@]} == 0 )) && return 0

    say "Installing build dependencies: ${missing[*]}"
    local sudo=
    (( EUID == 0 )) || sudo=sudo
    $sudo apt-get update
    $sudo apt-get install -y --no-install-recommends "${missing[@]}"
}

check_rust() {
    command -v "$CARGO" >/dev/null || die "cargo not found: $CARGO"
    local ver
    ver=$("$CARGO" --version | awk '{print $2}')
    say "Using $("$CARGO" --version)"
    if ! printf '1.85.0\n%s\n' "$ver" | sort -V -C; then
        die "Rust >= 1.85 is required (found $ver)"
    fi
}

# fetch_source REPO TAG DIR
fetch_source() {
    local repo=$1 tag=$2 dir=$3
    if [[ -d $dir/.git ]]; then
        say "Updating $(basename "$dir") to $tag"
        git -C "$dir" fetch --depth 1 origin tag "$tag"
        git -C "$dir" checkout -q --force "$tag"
    else
        say "Cloning $repo at $tag"
        git clone -q --depth 1 --branch "$tag" "$repo" "$dir"
    fi
}

# shlib_depends BINARY... : runtime library dependencies, dpkg-shlibdeps style
shlib_depends() {
    local tmp
    tmp=$(mktemp -d)
    mkdir -p "$tmp/debian"
    printf 'Source: dummy\n\nPackage: dummy\nArchitecture: any\n' > "$tmp/debian/control"
    (cd "$tmp" && dpkg-shlibdeps -O "$@" 2>/dev/null) \
        | sed -n 's/^shlibs:Depends=//p'
    rm -rf "$tmp"
}

# make_deb NAME VERSION ROOTDIR DEPENDS RECOMMENDS DESCRIPTION
make_deb() {
    local name=$1 version=$2 root=$3 depends=$4 recommends=$5 desc=$6
    local arch size deb
    arch=$(dpkg --print-architecture)
    size=$(du -sk --exclude=DEBIAN "$root" | cut -f1)

    mkdir -p "$root/DEBIAN"
    {
        echo "Package: $name"
        echo "Version: $version"
        echo "Architecture: $arch"
        echo "Maintainer: $MAINTAINER"
        echo "Installed-Size: $size"
        echo "Depends: $depends"
        [[ -n $recommends ]] && echo "Recommends: $recommends"
        echo "Section: x11"
        echo "Priority: optional"
        echo "Description: $desc"
    } > "$root/DEBIAN/control"

    deb="$WORK_DIR/${name}_${version}_${arch}.deb"
    fakeroot dpkg-deb --build -Zxz "$root" "$deb" >/dev/null
    say "Built $(basename "$deb")"
    DEBS+=("$deb")
}

#------------------------------------------------------------------------------
build_niri() {
    local src=$WORK_DIR/niri root=$WORK_DIR/pkg-niri version
    fetch_source "$NIRI_REPO" "$NIRI_VERSION" "$src"

    say "Building niri $NIRI_VERSION (this takes a while)"
    (cd "$src" && "$CARGO" build --release --locked -j "$JOBS")

    version="${NIRI_VERSION#v}-$DEB_REVISION"
    rm -rf "$root"
    install -Dm755 "$src/target/release/niri"           "$root/usr/bin/niri"
    strip --strip-unneeded "$root/usr/bin/niri"       # the release profile keeps debug info
    install -Dm755 "$src/resources/niri-session"        "$root/usr/bin/niri-session"
    install -Dm644 "$src/resources/niri.desktop"        "$root/usr/share/wayland-sessions/niri.desktop"
    install -Dm644 "$src/resources/niri-portals.conf"   "$root/usr/share/xdg-desktop-portal/niri-portals.conf"
    install -Dm644 "$src/resources/niri.service"        "$root/usr/lib/systemd/user/niri.service"
    install -Dm644 "$src/resources/niri-shutdown.target" "$root/usr/lib/systemd/user/niri-shutdown.target"
    install -Dm644 "$src/resources/default-config.kdl"  "$root/usr/share/doc/niri/default-config.kdl"
    install -Dm644 "$src/LICENSE"                       "$root/usr/share/doc/niri/copyright"

    # libwayland-server is loaded at runtime, so shlibdeps cannot see it.
    local depends
    depends="$(shlib_depends "$root/usr/bin/niri"), libwayland-server0"
    make_deb niri "$version" "$root" "$depends" \
        "xwayland-satellite, xdg-desktop-portal-gnome, xdg-desktop-portal-gtk, gnome-keyring, mako-notifier, fuzzel, waybar" \
        "scrollable-tiling Wayland compositor
 Windows are arranged in columns on an infinite strip going to the right.
 Built from upstream $NIRI_VERSION for the MX Linux niri flavour."

    # The skel config of the theme is derived from the upstream default config:
    # warn when the packaged version ships a different one.
    local theme_cfg=$TOP_DIR/Themes/mxniri/skel-config/niri/config.kdl
    if [[ -f $theme_cfg ]] \
        && ! grep -qxF 'spawn-at-startup "niri-mx-autostart"' "$theme_cfg"; then
        say "Warning: review $theme_cfg against $src/resources/default-config.kdl"
    fi
}

build_xwayland_satellite() {
    local src=$WORK_DIR/xwayland-satellite root=$WORK_DIR/pkg-xws version
    fetch_source "$XWS_REPO" "$XWS_VERSION" "$src"

    say "Building xwayland-satellite $XWS_VERSION"
    (cd "$src" && "$CARGO" build --release --locked -j "$JOBS")

    version="${XWS_VERSION#v}-$DEB_REVISION"
    rm -rf "$root"
    install -Dm755 "$src/target/release/xwayland-satellite" "$root/usr/bin/xwayland-satellite"
    strip --strip-unneeded "$root/usr/bin/xwayland-satellite"
    install -Dm644 "$src/LICENSE" "$root/usr/share/doc/xwayland-satellite/copyright"

    make_deb xwayland-satellite "$version" "$root" \
        "$(shlib_depends "$root/usr/bin/xwayland-satellite"), xwayland" "" \
        "Xwayland outside your Wayland compositor
 Rootless Xwayland integration, used by niri to run X11 applications.
 Built from upstream $XWS_VERSION for the MX Linux niri flavour."
}

#------------------------------------------------------------------------------
main() {
    DEBS=()
    mkdir -p "$WORK_DIR"
    install_build_deps
    check_rust

    build_niri
    build_xwayland_satellite

    local dir
    for dir in "${OUT_DIRS[@]}"; do
        mkdir -p "$dir"
        rm -f "$dir"/niri_*.deb "$dir"/xwayland-satellite_*.deb
        cp "${DEBS[@]}" "$dir"/
        say "Copied packages to ${dir#"$TOP_DIR"/}/"
    done

    say "Done. Check the packages with:  dpkg-deb -I Deb/mxniri/niri_*.deb"
}

main "$@"
