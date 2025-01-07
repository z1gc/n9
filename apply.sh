#!/usr/bin/env bash

set -ue

if ! which sudo &> /dev/null; then
    echo "Have no sudo!"
    exit 1
fi

COMTRYA=comtrya
DISK=
SUBDISK=
WIPE=false
SECRET=

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
    "-s")
        SECRET="$2"
        shift 2
    ;;
    "-t")
        set -x
        COMTRYA="comtrya -vv"
        shift 1
    ;;
    "-h")
        echo "$0 [OPTIONS] MACHINE [ROOT]"
        echo "    -h         This (un)helpful message"
        echo "    -t         Enable trace output, may be a mess"
        echo "    -p DISK    Mount the disk if is already set up"
        echo "    -w         Partition the disk (DANGEROUS!)"
        echo "    -s SECRET  Asterisk, give me a secret, and more"
        echo "If nothing supplies, MACHINE wll be set to $(hostname)"
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
fi

# To here, or to tmp (TODO: cleanup?):
cd "$(dirname "${BASH_SOURCE[0]}")"
if [[ ! -d .git ]]; then
    mkdir -p /tmp/n9
    cd /tmp/n9
    MANIFEST=https://github.com/z1gc/n9
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

# We have secrets, for sure:
if [[ "$SECRET" != "" ]]; then
    if [[ "${SSH_AUTH_SOCK:-}" == "" ]]; then
        eval "$(ssh-agent -s)"
        # shellcheck disable=SC2064
        trap "kill $SSH_AGENT_PID" SIGINT SIGTERM EXIT
    fi
    ENVS_SUDO+=("SSH_AUTH_SOCK=$SSH_AUTH_SOCK")
    curl -L "https://ptr.ffi.fyi/asterisk?hash=$SECRET" | bash -s
fi

SUDO="sudo"
if (( ${#ENVS_SUDO[@]} != 0 )); then
    SUDO+=" env ${ENVS_SUDO[*]}"
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
  channel: "24.11"
  root: "$ROOT"
  disk: "$DISK"
  partition: "$DISK$SUBDISK"
  wipe: $WIPE
  secret: "$SECRET"
EOF

# Apply! TODO: Can we have only the nix, without comtrya's bootstrap?
for stage in nixos.s nixos.o; do
    # shellcheck disable=SC2086
    $SUDO $COMTRYA -c .comtrya.yaml -d $MANIFEST apply -m $stage
done
