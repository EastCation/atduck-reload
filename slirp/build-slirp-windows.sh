#!/bin/sh
#
# Build SLiRP for Windows (run this inside a Cygwin shell, or any POSIX
# environment with a C compiler). It produces ./slirp-nandhp-patch.exe,
# which ATduck's dialing plan (5555=PPP, 5556=SLIP) uses to provide NAT /
# internet access.
#
# ATduck does not bundle the SLiRP source, only the two patches below that
# fix Cygwin and PPP issues. This helper downloads the Debian/Ubuntu
# slirp 1.0.17 source, applies the patches, and builds it.
#
# Prerequisites (Cygwin): gcc, make, m4, autoconf, automake, cvs
#   (run `setup-x86_64.exe` / `setup-x86.exe` and install these packages)

set -e

cd "$(dirname "$0")"

SRCDIR=slirp-1.0.17
SRCTARBALL=$SRCDIR.tar.gz
SLIRP_TGZ_URLS="
http://archive.debian.org/debian/pool/main/s/slirp/slirp_1.0.17.orig.tar.gz
http://security.ubuntu.com/ubuntu/pool/universe/s/slirp/slirp_1.0.17.orig.tar.gz
"

# 1. Obtain the source tree if we do not already have it.
if [ ! -d "$SRCDIR" ]; then
    if [ ! -f "$SRCTARBALL" ]; then
        ok=
        for url in $SLIRP_TGZ_URLS; do
            echo "Downloading $url"
            if curl -fL -o "$SRCTARBALL" "$url" 2>/dev/null ||
               wget -q -O "$SRCTARBALL" "$url" 2>/dev/null; then
                ok=1; break
            fi
        done
        if [ -z "$ok" ]; then
            echo "ERROR: could not download $SRCTARBALL automatically." >&2
            echo "Please place slirp_1.0.17.orig.tar.gz (the standard slirp" >&2
            echo "1.0.17 source from Debian/Ubuntu) in $PWD and re-run." >&2
            exit 1
        fi
    fi
    tar xzf "$SRCTARBALL"
fi

# 2. Apply the included patches (idempotent: skip hunks already applied).
apply_patch() {
    # `reverse-apply` counts as applied; failure means it needs applying.
    if patch -p1 --dry-run -R < "$1" >/dev/null 2>&1; then
        echo "Already applied: $1"
        return
    fi
    echo "Applying $1"
    patch -p1 --forward < "$1"
}

cd "$SRCDIR"
apply_patch ../slirp-cygwin-compat.patch
apply_patch ../slirp-ppp-fakeip.patch

# 3. Configure and build.
#    (--disable-dns makes the build simpler; slirp still does NAT.)
./configure --disable-dns
make proclean 2>/dev/null || true   # clear prototype cache so the patches take effect
make

# 4. Install as ATduck's SLiRP binary.
cp -f slirp "$OLDPWD/slirp-nandhp-patch.exe"
echo
echo "Built ./slirp-nandhp-patch.exe"
echo "Start ATduck and dial 5555 (PPP) or 5556 (SLIP) for NAT internet access."