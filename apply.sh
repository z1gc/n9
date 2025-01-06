#!/usr/bin/env bash

set -ue

SUDO="$(which sudo) env"
if [[ "$SUDO" == " env" ]]; then
    echo "Have no sudo!"
    exit 1
fi

# For nix, it's better not to use -E, which will pollutes the $HOME or other
# envs. We keep a workaround to pass some envs here, like `env_keep` in sudo.
if [[ "${HTTPS_PROXY:-}" != "" ]]; then
    SUDO+=" HTTPS_PROXY=$HTTPS_PROXY"
fi

DISK=
PARTITION=
WIPE=false
REMOTE=false
YES=false

# Arguments parsing:
while true; do
    case "${1:-}" in
    "-p")
        DISK="${2:-}"
        shift 2
    ;;
    "-w")
        WIPE=true
        shift 1
    ;;
    "-y")
        YES=true
        shift 1
    ;;
    "-g")
        REMOTE=true
        shift 1
    ;;
    *)
        break
    ;;
    esac
done

MANIFEST=nixos
MACHINE="${1:-}"
ROOT="${2:-}"
ROOT="${ROOT%/}"

if [[ "$MACHINE" == "" ]]; then
    echo "$0 [OPTIONS] MACHINE [ROOT]"
    echo "    -p DISK    Mount the disk if is already set up"
    echo "    -w         Partition the disk (DANGEROUS!)"
    echo "    -y         Yes for all, don't even ask"
    echo "    -g         Test remote manifest via git"
    exit 1
fi

if [[ "$DISK" != "" ]]; then
    if [[ "$ROOT" == "" ]]; then
        echo "Must set a mountpoint (e.g. /mnt)"
        exit 1
    fi

    # Verify the disk is really a disk:
    IFS=, read -r TYPE MAJOR MINOR < <(LC_ALL=C stat -c %F,%Hr,%Lr "$DISK")
    if [[ "$TYPE" != "block special file" ]]; then
        echo "Not a block device! Check it."
        exit 1
    fi

    # https://www.kernel.org/doc/html/latest/admin-guide/devices.html
    case "$MAJOR" in
        "8")
            # /dev/sda1
        ;;
        "253")
            # /dev/vda1
        ;;
        "259")
            # /dev/nvme0n1p1
            PARTITION=p
        ;;
        *)
            echo "Invalid disk, report it."
            exit 1
        ;;
    esac

    if (( MINOR != 0 )); then
        echo "Subpartition provided, won't deal with that :/"
        exit 1
    fi

    if ! $YES; then
        read -p "The $DISK will be destroyed! Y? " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
fi

# To here, or to tmp (TODO: cleanup?):
cd "$(dirname "${BASH_SOURCE[0]}")"
if $REMOTE || [[ ! -d .git ]]; then
    mkdir -p /tmp/n9
    cd /tmp/n9
    MANIFEST=https://github.com/z1gc/n9#main:nixos
fi

# Check comtrya:
if ! $SUDO which comtrya &> /dev/null; then
    $SUDO nix-channel --add https://github.com/z1gc/n9/archive/main.tar.gz n9
    $SUDO nix-channel --update n9
    $SUDO nix-env -iA n9.comtrya

    if ! $SUDO comtrya version; then
        echo "Install comtrya failed, maybe you have solutions?"
        exit 1
    fi
fi

# Generate config:
cat > .comtrya.yaml <<EOF
variables:
  machine: "$MACHINE"
  root: "$ROOT"
  disk: "$DISK"
  partition: "$PARTITION"
  wipe: "$WIPE"
EOF

# Apply!
$SUDO comtrya -v -c .comtrya.yaml -d $MANIFEST apply -m "$MACHINE"

echo "Next step (run either one manually):"
echo "    => $SUDO nixos-install"
echo " or => $SUDO nixos-rebuild switch --upgrade"
echo "(Don't forget to check your \"$ROOT/etc/nixos\"!)"
