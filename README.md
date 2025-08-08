This is my Nix setup managing multiple configurations with a modular structure:
- **nixos**: Full desktop setup with GUI applications
- **work**: Also full desktop setup but for a secondary work host
- **android**: Terminal-only setup for nix-on-droid

The configurations use a layered approach:
- `terminal.nix`: Core CLI tools and terminal configs (shared by all)
- `gui.nix`: GUI applications and desktop configs

- NixOS documentation [here](https://nixos.org/manual/nixos/unstable/)
- Flakes info [here](https://wiki.nixos.org/wiki/Flakes)

## Usage

Build NixOS config (GUI + terminal):
```bash
sudo nixos-rebuild switch --flake ~/.config/nix#nixos
```

Build work config (GUI + terminal but with work home):
```bash
home-manager switch --flake ~/.config/nix#work
```

Build Android config (terminal only):
```bash
nix-on-droid switch --flake ~/.config/nix#default
```

## Structure
```bash
.
├── flake.lock
├── flake.nix
├── home
│   ├── gui.nix          # GUI only
│   └── terminal.nix     # terminal only
├── hosts
│   ├── android
│   │   └── default.nix  # imports terminal.nix
│   ├── home
│   │   └── default.nix  # imports gui.nix and terminal.nix
│   └── work
│       └── default.nix  # imports gui.nix and terminal.nix
├── nixos
│   ├── configuration.nix
│   └── hardware-configuration.nix
└── README.md
```

