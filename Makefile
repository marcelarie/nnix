.PHONY: format nixos nixos-nixbuild mlab nixos-nixbuild-mlab droid hm news sops android-mirror whatsapp-register azuracast-deploy

lint: 
	@nix run .#ruff -- check --fix

format:
	@nix run .#ruff -- format
	@nix run .#oxfmt -- .
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

# push only the azuracast public custom css/js to the live box, no full nixos rebuild.
# the css/js live in azuracast's settings db (applied via azuracast_cli in default.nix), so this
# just cats the local files into `azuracast:settings:set` over ssh. no container or radio restart
# needed - the public page picks the new css/js up on next load.
azuracast-deploy:
	@if ssh -q -o ConnectTimeout=5 root@mlab-local exit 2>/dev/null; then HOST=root@mlab-local; else HOST=root@mlab; fi; \
	echo "Pushing azuracast css/js to $$HOST..."; \
	scp hosts/mlab/azuracast/azuracast-public.css hosts/mlab/azuracast/azuracast-public.js $$HOST:/tmp/ && \
	ssh $$HOST 'podman exec azuracast azuracast_cli azuracast:settings:set public_custom_css "$$(cat /tmp/azuracast-public.css)" && podman exec azuracast azuracast_cli azuracast:settings:set public_custom_js "$$(cat /tmp/azuracast-public.js)" && rm -f /tmp/azuracast-public.css /tmp/azuracast-public.js' && \
	echo "azuracast css/js updated on $$HOST."

