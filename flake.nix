{
  description = "NixOS and Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgsStable.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixGL = {
      url = "github:nix-community/nixGL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mq.url = "github:marcelarie/mq";
    tmex = {
      url = "github:marcelarie/tmex";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
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
    ...
  } @ inputs: let
    system = "x86_64-linux";
    androidSystem = "aarch64-linux";
    username = "marcel";
    hostname = "nixos";
    tmexPkg = tmex.packages.${system}.tmex;
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [
        (import ./overlays/neovim-nightly.nix {inherit inputs;})
        (final: prev: {tmex = tmexPkg;})
      ];
    };
    pkgsAndroid = import nixpkgs {
      system = androidSystem;
      config.allowUnfree = true;
      overlays = [
        (import ./overlays/neovim-nightly.nix {inherit inputs;})
      ];
    };
    pkgsStable = import nixpkgsStable {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [git nix-prefetch cachix];
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
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.${username} = import ./hosts/home/default.nix;
            backupFileExtension = "backup";
            extraSpecialArgs = {inherit inputs pkgsStable;};
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
