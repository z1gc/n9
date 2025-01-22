export HOSTNAME ?= $(shell hostname)
FLAKE = ./octothorp/${HOSTNAME}
GARBAGE = nix-collect-garbage --delete-older-than 2d
NIX = nix --extra-experimental-features 'nix-command flakes'

ifneq ($(shell grep '\s*nixosConfigurations\s*=' "${FLAKE}/flake.nix"),)
# ======= NixOS
ifneq (${USER},root)
$(error Run as root or sudo)
endif

ifneq (${SUDO_USER},)
RUNAS = su "${SUDO_USER}"
else
RUNAS = su "$(shell stat -c %U .git)"
endif

HWCONF = ${FLAKE}/hardware-configuration.nix

${HWCONF}:
	nixos-generate-config --no-filesystems --show-hardware-config > "$@"

setup: ${HWCONF}
	grep -Eq 'VARIANT_ID="?installer"?' /etc/os-release
	${NIX} build --no-link --print-out-paths --no-write-lock-file \
		"${FLAKE}#nixosConfiguration.${HOSTNAME}.config.system.build.diskoScript" \
		| bash -s
	nixos-install --no-root-password --no-channel-copy --flake \
		"${FLAKE}#${HOSTNAME}"
	if test -f asterisk/Makefile; then ${MAKE} -C asterisk setup; fi

garbage:
	${GARBAGE}
	${RUNAS} -c "${GARBAGE}"

switch: ${HWCONF} garbage
	rm -f "${FLAKE}/flake.lock"
	nixos-rebuild switch --show-trace --flake "${FLAKE}#${HOSTNAME}"
	if test -f asterisk/Makefile; then ${MAKE} -C asterisk switch; fi
# ======= End NixOS
else
# ======= HomeManager
RUNAS = bash -c

setup:
	sudo -v
	curl -L https://nixos.org/nix/install | bash -s -- --daemon --yes
	bash -i -c "${NIX} run home-manager/master --init --switch --flake ${FLAKE}"
	if test -f asterisk/Makefile; then ${MAKE} -C asterisk setup; fi
	@echo "You should restart/relogin the shell."

gargabe:
	${GARBAGE}

switch:
	rm -f "${FLAKE}/flake.lock"
	home-manager switch --show-trace --flake ${FLAKE}
	if test -f asterisk/Makefile; then ${MAKE} -C asterisk switch; fi
# ======= End HomeManager
endif

# The make will treat the result/outpu of `$(...)` as a receipt, therefore we
# need to clear out the stdout.
$(shell ${RUNAS} -c "git pull --rebase --recurse-submodules" 1>&2)
$(shell chmod -R g-rw,o-rw asterisk 1>&2)

.PHONY: setup garbage switch
.DEFAULT_GOAL = switch
