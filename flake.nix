{
  description = "NixOS and Home Manager configuration";

  inputs = {
    mq.url = "github:marcelarie/mq";
    ki-editor.url = "github:ki-editor/ki-editor";
    musnix.url = "github:musnix/musnix";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgsStable.url = "github:NixOS/nixpkgs/nixos-25.11";
    nu-alias-converter.url = "github:marcelarie/nu-alias-converter";
    nur.url = "github:nix-community/NUR";
    lsv = {
      url = "path:./packages/lsv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    audio-select = {
      url = "path:./packages/audio-select";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rff = {
      url = "path:./packages/rff";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pulseaudio-next-output = {
      url = "path:./packages/pulseaudio-next-output";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    git-commit-search = {
      url = "path:./packages/git-commit-search";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    haralyzer = {
      url = "path:./packages/haralyzer";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    foot-fork = {
      url = "git+https://codeberg.org/marcelarie/foot";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zuban.url = "github:marcelarie/zuban";
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixGL = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tmex = {
      url = "github:marcelarie/tmex";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland = {
      url = "github:hyprwm/Hyprland";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    hyprland-plugins = {
      url = "github:hyprwm/hyprland-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.hyprland.follows = "hyprland";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgsStable,
    nixGL,
    home-manager,
    nix-on-droid,
    tmex,
    neovim-nightly-overlay,
    nu-alias-converter,
    lsv,
    audio-select,
    rff,
    pulseaudio-next-output,
    git-commit-search,
    haralyzer,
    zen-browser,
    nur,
    ...
  } @ inputs: let
    hyprlandInputs = inputs.hyprland;
    hyprlandPlugins = inputs."hyprland-plugins";
    system = "x86_64-linux";
    androidSystem = "aarch64-linux";
    username = "marcel";
    hostname = "nixos";
    tmexPkg = tmex.packages.${system}.tmex;
    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowUnfree = true;
        permittedInsecurePackages = [
          "qtwebengine-5.15.19"
        ];
      };
      overlays = [
        # hyprlandInputs.overlays.default
        # hyprlandPlugins.overlays.default
        nur.overlays.default
        (import ./overlays/neovim-nightly.nix {inherit inputs;})
        (final: prev: {tmex = tmexPkg;})
        (final: prev: {nuit = nu-alias-converter.packages.${system}.default;})
        (final: prev: {lsv = inputs.lsv.packages.${system}.default;})
        (final: prev: {"audio-select" = inputs.audio-select.packages.${system}.default;})
        (final: prev: {rff = inputs.rff.packages.${system}.default;})
        (final: prev: {"pulseaudio-next-output" = inputs.pulseaudio-next-output.packages.${system}.default;})
        (final: prev: {"git-commit-search" = inputs.git-commit-search.packages.${system}.default;})
        (final: prev: {haralyzer = inputs.haralyzer.packages.${system}.default;})
        (final: prev: {foot = inputs.foot-fork.packages.${system}.default;})
        (final: prev: {zuban = inputs.zuban.packages.${system}.default;})
        (final: prev: {"ki-editor" = inputs.ki-editor.packages.${system}.default;})
      ];
    };
    pkgsAndroid = import nixpkgsStable {
      system = androidSystem;
      config.allowUnfree = true;
    };
    pkgsStable = import nixpkgsStable {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [git nix-prefetch];
      shellHook = ''
        echo "🐚  Dev shell for ${username} on ${system} ready!"
        export EDITOR=nvim
      '';
    };

    nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
      inherit system pkgs;
      specialArgs = {inherit inputs pkgsStable;};
      modules = [
        ./nixos/configuration.nix
        ./nixos/hardware-configuration.nix
        inputs.musnix.nixosModules.musnix
        inputs.sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.${username} = import ./hosts/home/default.nix;
            backupFileExtension = "backup";
            extraSpecialArgs = {inherit inputs pkgsStable nixGL;};
          };
        }
      ];
    };

    homeConfigurations = {
      work = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        extraSpecialArgs = {inherit inputs pkgsStable nixGL;};
        modules = [
          ./home/gui.nix
          ./home/terminal.nix
          ./hosts/work/default.nix
          ({
            config,
            pkgs,
            nixGL,
            ...
          }: {
            home.username = "mmanzanares";
            home.homeDirectory = "/home/mmanzanares";
            targets.genericLinux.enable = true;

            nixGL = {
              packages = nixGL.packages;
              defaultWrapper = "mesa";
            };
          })
        ];
      };
    };

    nixOnDroidConfigurations.default = nix-on-droid.lib.nixOnDroidConfiguration {
      pkgs = pkgsAndroid;
      modules = [
        ./hosts/android/default.nix
      ];
    };
  };
}
