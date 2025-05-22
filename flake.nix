{
  description = "NixOS and Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgsStable.url = "github:NixOS/nixpkgs/nixos-24.11";
    tmex = {
      url = "github:marcelarie/tmex";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    nixpkgsStable,
    home-manager,
    tmex,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    username = "marcel";
    hostname = "nixos";
    tmexPkg = tmex.packages.${system}.tmex;
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [
        (final: prev: {
          tmex = tmexPkg;
        })
      ];
    };
    pkgsStable = import nixpkgsStable {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = with pkgs; [
        git
        nix-prefetch
        cachix
      ];
      shellHook = ''
        echo "🐚  Dev shell for ${username} on ${system} ready!"
        export EDITOR=nvim
      '';
    };

    nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
      inherit system pkgs;
      modules = [
        ./nixos/configuration.nix
        ./nixos/hardware-configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.${username} = import ./home/marcel.nix;
            backupFileExtension = "backup";
            extraSpecialArgs = {
              inherit pkgsStable;
            };
          };
        }
      ];
    };

    homeConfigurations = {
      work = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          ./home/common.nix
          ./hosts/work/default.nix
          {
            home.username = "mmanzanares";
            home.homeDirectory = "/home/mmanzanares";
            targets.genericLinux.enable = true;
          }
        ];
      };
    };
  };
}
