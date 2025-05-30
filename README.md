This iss my Nix setup, and it manages two configurations: nixos and work.
Both share a common home/common.nix to keep things consistent across environments.

- NixOS documentation [here](https://nixos.org/manual/nixos/unstable/)
- Flakes info [here](https://wiki.nixos.org/wiki/Flakes)

Build NixOS config (common + home) with:
```bash
sudo nixos-rebuild switch --flake ~/.config/nix#nixos
```
Build secondary config (common + work) with:
```bash
home-manager switch --flake ~/.config/nix#work
```
The work configuration is portable and can be applied on any system with Nix and
Home Manager installed.

Structure:
```
.
├── flake.lock
├── flake.nix
├── home
│   └── common.nix
├── hosts
│   ├── home
│   │   └── default.nix
│   └── work
│       └── default.nix
├── nixos
│   ├── configuration.nix
│   └── hardware-configuration.nix
└── README.md
```

