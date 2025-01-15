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
  local secret="$1" clone=(git clone)
  if [[ "$secret" != "" ]]; then
      if [[ "${SSH_AUTH_SOCK:-}" == "" ]]; then
          eval "$(ssh-agent -s)"
          # shellcheck disable=SC2064
          trap "kill $SSH_AGENT_PID" SIGINT SIGTERM EXIT
      fi
      curl -L "ptr.ffi.fyi/asterisk?hash=$secret" | bash -s
      clone+=(--recursive)
  fi

  cd "$(dirname "${BASH_SOURCE[0]}")"
  if ! grep -Fq z1gc/n9 .git/config; then
      "${clone[@]}" "https://github.com/z1gc/n9.git" .n9
      cd .n9
  fi

  git pull --rebase --recurse-submodules || true
  chmod -R g-rw,o-rw asterisk
  cd nixos
}

function setup() {
  local ssh="$1" port="$2" hostname="$3" args=()

  if [[ "$ssh" != "" ]]; then
    args+=(--target-host "$ssh")
    if [[ "$port" != "" ]]; then
      args+=(--ssh-port "$port")
    fi
  fi

  nixos-hardware "$ssh" "$port" "$hostname"
  nixos-anywhere --flake ".#$hostname" "${args[@]}"
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

function main() {
  local op=exit secret ssh port
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
    "-h")
      echo "$0 [OPTIONS] HOSTNAME"
      echo "    -h        This (un)helpful message"
      echo "    -s SECRET Asterisk, give me a secret"
      echo "    -t SSH    Remote, format as \"HOST:PORT\""
      echo "If nothing, HOSTNAME will set to $(hostname)"
      exit
  esac

  init "${secret:-}"
  $op "${ssh:-}" "${port:-}" "${1:-"$(hostname)"}"
}

main "$@"
