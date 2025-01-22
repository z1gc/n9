ifneq (${USER},root)
$(error Run as root or sudo)
endif

export HOSTNAME ?= $(shell hostname)

# The make will treat the result/outpu of `$(...)` as a receipt, therefore we
# need to clear out the stdout.
$(shell su $$(stat -c %U .git) -c "git pull --rebase --recurse-submodules" 1>&2)
$(shell chmod -R g-rw,o-rw asterisk 1>&2)

FLAKE = ./dev/${HOSTNAME}
HWCONF = dev/${HOSTNAME}/hardware-configuration.nix

${HWCONF}:
	nixos-generate-config --no-filesystems --show-hardware-config > "$@"

setup: ${HWCONF}
	grep -Eq 'VARIANT_ID="?installer"?' /etc/os-release
	nix build --extra-experimental-features "nix-command flakes" --no-link \
		--print-out-paths --no-write-lock-file \
		"${FLAKE}#nixosConfiguration.${HOSTNAME}.config.system.build.diskoScript" \
		| bash -s
	nixos-install --no-root-password --no-channel-copy --flake \
		"${FLAKE}#${HOSTNAME}"
	if test -f asterisk/Makefile; then ${MAKE} -C asterisk setup; fi

switch: ${HWCONF}
	rm -f "dev/${HOSTNAME}/flake.lock"
	nixos-rebuild switch --show-trace --flake "${FLAKE}#${HOSTNAME}"
	nix-env --profile /nix/var/nix/profiles/system --delete-generations +7
	if test -f asterisk/Makefile; then ${MAKE} -C asterisk switch; fi

garbage:
	nix-store --gc

.PHONY: setup switch garbage
.NOTPARALLEL:
.DEFAULT_GOAL = switch
