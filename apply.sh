#!/usr/bin/env bash

set -ue

if ! which sudo &> /dev/null; then
    echo "Have no sudo!"
    exit 1
fi

# For nix, it's better not to use -E, which will pollutes the $HOME or other
# envs. We keep a workaround to pass some envs here, like `env_keep` in sudo.
ENVS_SUDO=()
if [[ "${HTTPS_PROXY:-}" != "" ]]; then
    ENVS_SUDO+=("HTTPS_PROXY=$HTTPS_PROXY")
fi
if [[ "${NIX_CRATES_INDEX:-}" != "" ]]; then
    ENVS_SUDO+=("NIX_CRATES_INDEX=$NIX_CRATES_INDEX")
fi

SUDO="sudo"
if (( ${#ENVS_SUDO[@]} != 0 )); then
    SUDO+=" env ${ENVS_SUDO[*]}"
fi

CHANNEL="24.11"
DISK=
SUBDISK=
WIPE=false
REMOTE=false
YES=false

# Arguments parsing:
while true; do
    case "${1:-}" in
    "-p")
        DISK="$2"
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
    "-c")
        CHANNEL="$2"
        shift 2
    ;;
    "-h")
        echo "$0 [OPTIONS] MACHINE [ROOT]"
        echo "    -h         This (un)helpful message"
        echo "    -c CHANNEL Switch to other channel, e.g. 24.11"
        echo "    -p DISK    Mount the disk if is already set up"
        echo "    -w         Partition the disk (DANGEROUS!)"
        echo "    -y         Yes for all, don't even ask"
        echo "    -g         Test remote manifest via git"
        echo "If nothing supplies, MACHINE is the hostname"
        exit 1
    ;;
    *)
        break
    ;;
    esac
done

MANIFEST=.
MACHINE="${1:-"$(hostname)"}"
ROOT="${2:-}"
ROOT="${ROOT%/}"

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
            SUBDISK=p
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

    if $WIPE && ! $YES; then
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
    MANIFEST=https://github.com/z1gc/n9
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

# Generate config, using tee for dumping:
tee .comtrya.yaml <<EOF
variables:
  machine: "$MACHINE"
  channel: "$CHANNEL"
  root: "$ROOT"
  disk: "$DISK"
  partition: "$DISK$SUBDISK"
  wipe: $WIPE
EOF

# Apply!
# TODO: Can we have only the nix, without comtrya's bootstrap?
$SUDO comtrya -v -c .comtrya.yaml -d $MANIFEST apply -m nixos.g
