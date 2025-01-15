#!/usr/bin/env bash
# Wrapper of nixos-anywhere and nixos-rebuild.
# TODO: Install.

set -ue

function nixos-anywhere() {
  # shellcheck disable=SC2155
  local bin="$(which nixos-nixos-anywhere)"
  if [[ "$bin" != "" ]]; then
    $bin "$@"
  else
    nix run github:nix-community/nixos-anywhere -- "$@"
  fi
}

function nixos-hardware() {
  local ssh="$1" port="$2" hostname="$3" \
    cmd=(nixos-generate-config --no-filesystems --show-hardware-config)

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
  local secret="$1" repo="z1gc/n9" clone=(git clone)
  if [[ "$secret" != "" ]]; then
    if [[ "${SSH_AUTH_SOCK:-}" == "" ]]; then
      eval "$(ssh-agent -s)"
      # shellcheck disable=SC2064
      trap "kill $SSH_AGENT_PID" SIGINT SIGTERM EXIT
    fi
    curl -L "ptr.ffi.fyi/asterisk?hash=$secret" | bash -s
    clone+=(--recursive "git@github.com:$repo.git")
  else
    clone+=("https://github.com/$repo.git")
  fi

  cd "$(dirname "${BASH_SOURCE[0]}")"
  if ! grep -Fq "$repo" .git/config; then
    "${clone[@]}" .n9
    cd .n9
  fi

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
  nixos-rebuild switch --flake ".#$hostname" "${args[@]}"
}

function help() {
  echo "$0 setup|switch [OPTIONS] HOSTNAME"
  echo "    -s SECRET    Asterisk, give me a secret"
  echo "    -t HOST:PORT Remote, a ssh connection"
  echo "If nothing, HOSTNAME will set to \"$(hostname)\""
}

function main() {
  local op="" secret ssh port skip=false args=("$@")
  case "${1:-}" in
    "setup"|"switch")
      op=$1
      shift ;;
    "-s")
      secret="$2"
      shift 2 ;;
    "-t")
      IFS=":" read -r ssh port <<<"$2"
      shift 2 ;;
    "-n")
      skip=true
      shift ;;
  esac

  if [[ "$op" == "" ]]; then
    help
    exit
  fi

  if ! $skip; then
    init "${secret:-}"
  fi

  if [[ "$USER" != "root" ]]; then
    exec sudo ../burn.sh -n "${args[@]}"
  fi

  $op "${ssh:-}" "${port:-}" "${1:-"$(hostname)"}"
  if [[ -x "../asterisk/setup.sh" ]]; then
    ../asterisk/setup.sh "${args[@]}"
  fi
}

main "$@"
