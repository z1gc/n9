#!/usr/bin/env bash
# Wrapper of nixos-anywhere and nixos-rebuild.
# TODO: Install as a nix package.

set -ue

function nixos-anywhere() {
  # shellcheck disable=SC2155
  local bin="$(which nixos-nixos-anywhere)"
  if [[ "$bin" != "" ]]; then
    sudo "$bin" "$@"
  else
    sudo nix run --extra-experimental-features "nix-command flakes" \
      github:nix-community/nixos-anywhere -- "$@"
  fi
}

function nixos-hardware() {
  local ssh="$1" port="$2" hostname="$3" \
    cmd=(sudo nixos-generate-config --no-filesystems --show-hardware-config)

  if [[ "$ssh" != "" ]]; then
    local args=()
    if [[ "$port" != "" ]]; then
      args+=(-p "$port")
    fi

    # shellcheck disable=SC2087
    ssh -t -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no \
      "${args[@]}" "$ssh" bash <<EOF
set -eu
export PATH="\$PATH:/run/current-system/sw/bin"
${cmd[@]}
EOF
  else
    "${cmd[@]}"
  fi > "$hostname/hardware-configuration.nix"
}

function init() {
  cd "$(dirname "${BASH_SOURCE[0]}")"
  git pull --rebase --recurse-submodules || true
  chmod -R g-rw,o-rw asterisk
  cd nixos
}

function setup() {
  local ssh="$1" port="$2" hostname="$3" args=()

  if [[ "$ssh" == "" ]]; then
    exit 1
  elif [[ "$port" != "" ]]; then
    args+=(--ssh-port "$port")
  fi

  # TODO: Setup own private key?
  nixos-hardware "$ssh" "$port" "$hostname"
  nixos-anywhere --flake ".#$hostname" "${args[@]}" \
    --phases kexec,disko,install "$ssh"
}

function switch() {
  local ssh="$1" port="$2" hostname="$3" args=()

  if [[ "$ssh" != "" ]]; then
    args+=(--target-host "$ssh")
    if [[ "$port" != "" ]]; then
      export NIX_SSHOPTS="$NIX_SSHOPTS -p $port"
    fi
  fi

  nixos-hardware "$ssh" "$port" "$hostname"
  sudo nixos-rebuild switch --flake ".#$hostname" "${args[@]}"
}

function help() {
  echo "$0 setup|switch [OPTIONS] HOSTNAME"
  echo "    setup             For a new build, wipes disk!"
  echo "    switch            Make a nixos-rebuild switch"
  echo "    -t USER@HOST:PORT Remote, a ssh connection"
  echo "If nothing, HOSTNAME will set to \"$(hostname)\""
}

function main() {
  local op="" ssh port hostname args=("$@")
  while [[ "${1:-}" != "" ]]; do
    case "${1:-}" in
      "setup"|"switch")
        op=$1
        shift ;;
      "-t")
        IFS=":" read -r ssh port <<<"$2"
        shift 2 ;;
      *)
        hostname="$1"
        shift ;;
    esac
  done

  if [[ "$op" == "" ]]; then
    help
    exit
  fi

  init
  $op "${ssh:-}" "${port:-}" "${hostname:-"$(hostname)"}"

  if [[ -x "../asterisk/setup.sh" ]]; then
    ../asterisk/setup.sh "${args[@]}"
  fi
}

main "$@"
