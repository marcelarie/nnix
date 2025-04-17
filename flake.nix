{
  description = "NixOS and Home Manager configuration";

  nixConfig = {
    extra-substituters = ["https://marcelarie.cachix.org"];
    extra-trusted-public-keys = [
      "marcelarie.cachix.org-1:loFQMIgWqiIgfRixHOrEwbGADvFYu8RJXF6jqL0HUy8="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    username = "marcel";
    hostname = "nixos";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./nixos/configuration.nix
        /etc/nixos/hardware-configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.${username} = import ./home.nix;
            backupFileExtension = "backup";
          };
        }
      ];
    };
  };
}
