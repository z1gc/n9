#!/usr/bin/env bash

set -ue

DISK=
PARTITION=

# Arguments parsing:
while true; do
    case "${1:-}" in
    "-p")
        DISK="${2:-}"
        shift 2
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
    echo "    -p DISK    Partition the disk (DANGEROUS!)"
    exit 1
fi

if [[ "$DISK" != "" ]]; then
    read -p "The $DISK will be destroyed! Y? " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi

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
fi

# To here, or to tmp (TODO: cleanup?):
cd "$(dirname "${BASH_SOURCE[0]}")"
if [[ ! -d .git ]]; then
    mkdir -p /tmp/unstable
    cd /tmp/unstable
    MANIFEST=https://github.com/z1gc/unstable#main:nixos
fi

# Check comtrya:
if [[ ! -f comtrya ]]; then
    # shellcheck disable=SC2016
    curl -fsSL https://get.comtrya.dev | sed 's/$BINLOCATION/./g' | bash || true
    if ! ./comtrya version; then
        rm -f ./comtrya
        echo "Wrong binary, please retry :("
        exit 1
    fi
fi

# Generate config:
cat > Comtrya.yaml <<EOF
variables:
    machine: "$MACHINE"
    root: "$ROOT"
    disk: "$DISK"
    partition: "$PARTITION"
EOF

# Apply!
sudo ./comtrya -v -d $MANIFEST apply -m "$MACHINE"
