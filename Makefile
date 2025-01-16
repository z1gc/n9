HOSTNAME ?= $(shell hostname)
HWCONF = dev/${HOSTNAME}/hardware-configuration.nix

${HWCONF}:
	sudo nixos-generate-config --no-filesystems --show-hardware-config > "$@"

setup: ${HWCONF}
	grep -Eq 'VARIANT_ID="?installer"?' /etc/os-release
	nix build --extra-experimental-features "nix-command flakes" --no-link \
		--print-out-paths --no-write-lock-file \
		".#nixosConfiguration.${HOSTNAME}.config.system.build.diskoScript" \
		| sudo bash -s
	sudo nixos-install --no-root-password --no-channel-copy --flake \
		".#${HOSTNAME}"
	if test -f asterisk/Makefile; then ${MAKE} -C asterisk setup; fi

switch: ${HWCONF}
	sudo nixos-rebuild switch --no-write-lock-file --flake ".#${HOSTNAME}"
	sudo nix-env --delete-generations +7
	if test -f asterisk/Makefile; then ${MAKE} -C asterisk switch; fi

clean:
	sudo nix-store --gc

.PHONY: setup switch clean
.NOTPARALLEL:
.DEFAULT_GOAL = switch
