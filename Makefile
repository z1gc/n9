export HOSTNAME ?= $(shell hostname)

# The make will treat the result/outpu of `$(shell)` as a receipt, therefore
# we need to clear out the stdout.
$(shell git pull --rebase --recurse-submodules 1>&2)
$(shell chmod -R g-rw,o-rw asterisk 1>&2)

# Main here:
FLAKE = dev/${HOSTNAME}?submodules=1
HWCONF = dev/${HOSTNAME}/hardware-configuration.nix

${HWCONF}:
	sudo nixos-generate-config --no-filesystems --show-hardware-config > "$@"

setup: ${HWCONF}
	grep -Eq 'VARIANT_ID="?installer"?' /etc/os-release
	nix build --extra-experimental-features "nix-command flakes" --no-link \
		--print-out-paths --no-write-lock-file \
		"${FLAKE}#nixosConfiguration.${HOSTNAME}.config.system.build.diskoScript" \
		| sudo bash -s
	sudo nixos-install --no-root-password --no-channel-copy --flake \
		"${FLAKE}#${HOSTNAME}"
	# if test -f asterisk/Makefile; then ${MAKE} -C asterisk setup; fi

# If within the installer, hmmm, that may be fine, or you may simply OOM.
switch: ${HWCONF}
	sudo find . -name flake.lock -exec rm -f {} \;
	sudo rm -f flake.lock
	sudo nixos-rebuild switch --show-trace --flake "${FLAKE}#${HOSTNAME}"
	sudo nix-env --delete-generations +7
	# if test -f asterisk/Makefile; then ${MAKE} -C asterisk switch; fi

gc:
	sudo nix-store --gc

# Meta here:
.PHONY: setup switch gc
.NOTPARALLEL:
.DEFAULT_GOAL = switch
