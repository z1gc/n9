#!/usr/bin/env bash

set -ue

for REQUIRED in sudo git; do
    if ! which $REQUIRED &> /dev/null; then
        echo "Have no $REQUIRED!"
        echo "(Try \"nix-env -iA nixos.$REQUIRED\"?)"
        exit 1
    fi
done

# TODO: Can we have only the nix, without miniya's bootstrap? Or nix-shell?
MINIYA=miniya
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
    "-v")
        set -x
        MINIYA+=" -vv"
        shift 1
    ;;
    "-h")
        echo "$0 [OPTIONS] MACHINE [ROOT]"
        echo "    -h         This (un)helpful message"
        echo "    -v         Enable trace output, may be a mess"
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
        "8"|"253")
            # /dev/sda1 | /dev/vda1
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

# We have secrets, for sure:
CLONE="git clone"
if [[ "$SECRET" != "" ]]; then
    if [[ "${SSH_AUTH_SOCK:-}" == "" ]]; then
        eval "$(ssh-agent -s)"
        # shellcheck disable=SC2064
        trap "kill $SSH_AGENT_PID" SIGINT SIGTERM EXIT
    fi
    curl -L "https://ptr.ffi.fyi/asterisk?hash=$SECRET" | bash -s
    CLONE+=" --recursive"
fi
# To where it lives:
cd "$(dirname "${BASH_SOURCE[0]}")"
if ! grep -Fq z1gc/n9 .git/config; then
    $CLONE https://github.com/z1gc/n9.git n9
    cd n9
fi
# Try to update if needs:
git pull --rebase --recurse-submodules || true
# Reset to secure permissions:
chmod -R g-rw,o-rw asterisk

if ! $SUDO which miniya &> /dev/null; then
    $SUDO nix-channel --add https://github.com/z1gc/n9/archive/main.tar.gz n9
    $SUDO nix-channel --update n9
    $SUDO nix-env -iA n9.miniya
fi

tee .miniya.yaml <<EOF
include_variables:
  - dev/$MACHINE.yaml

variables:
  machine: "$MACHINE"
  root: "$ROOT"
  disk: "$DISK"
  partition: "$DISK$SUBDISK"
  wipe: $WIPE
EOF

# shellcheck disable=SC2086
$SUDO $MINIYA -c .miniya.yaml -d . apply -m nixos.s
