.PHONY: format nixos nixos-nixbuild mlab nixos-nixbuild-mlab droid hm news sops

format:
	alejandra .

nixos:
	sudo nixos-rebuild switch --flake .#nixos

hm:
	home-manager switch --flake .#work

news:
	@if [ -f /etc/NIXOS ]; then \
		echo "On NixOS news shows during 'make nixos'."; \
	else \
		home-manager news --flake .#work; \
	fi

nixos-nixbuild:
	sudo nixos-rebuild switch --flake .#nixos \
		--option builders "@/tmp/nixbuild-machines" \
		--option builders-use-substitutes true \
		--option max-jobs 0

mlab:
	@if ssh -q -o ConnectTimeout=5 root@mlab-local exit 2>/dev/null; then \
		nixos-rebuild switch  --flake .#mlab --target-host root@mlab-local; \
	else \
		nixos-rebuild switch  --flake .#mlab --target-host root@mlab; \
	fi
	@# pin the mlab closure as a local GC root. 
	@# reuses the toplevel just built above (instant), just adds the root.
	@mkdir -p $(HOME)/.cache/nix-roots
	@nix build .#nixosConfigurations.mlab.config.system.build.toplevel --out-link $(HOME)/.cache/nix-roots/mlab

nixos-nixbuild-mlab:
	sudo nixos-rebuild switch --flake .#mlab --target-host root@mlab-local; \
		--option builders "@/tmp/nixbuild-machines" \
		--option builders-use-substitutes true \
		--option max-jobs 0

# a bit complex but its the only way I (claude) found so the phone does not do the build
droid:
	nix build .#nixOnDroidConfigurations.default.activationPackage --impure
	nix copy --to "ssh://nix-on-droid@droid?remote-program=/data/data/com.termux.nix/files/home/.nix-profile/bin/nix-store" ./result
	rsync -avz --delete --exclude='.git' --rsync-path="/data/data/com.termux.nix/files/home/.nix-profile/bin/rsync" ./ droid:~/.config/nix-on-droid/
	ssh droid "/data/data/com.termux.nix/files/home/.nix-profile/bin/bash -l -c 'nix-on-droid switch --flake ~/.config/nix-on-droid#default'"

sops:
	@selected=$$(ls secrets/ | fzf); \
	if [ -n "$$selected" ]; then \
		sops secrets/$$selected; \
	fi

# bootstrap zip for a fresh nix-on-droid install, impure by upstream design
bootstrap:
	nix build --impure --no-link --print-out-paths --expr 'let f = builtins.getFlake (toString ./.); in import ./hosts/android/bootstrap.nix { pkgs = f.inputs.nixpkgs.legacyPackages.x86_64-linux; nix-on-droid = f.inputs.nix-on-droid; system = "x86_64-linux"; targetSystem = "aarch64-linux"; sshKeyPath = ./hosts/android/ssh.pub; flakeSource = ./.; }'
