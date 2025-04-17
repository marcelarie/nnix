{
  description = "NixOS and Home Manager configuration";

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
    # TODO: Setup this so it does not appear like unknown
    # homeConfigurations = {
    #   ${username} = home-manager.lib.homeManagerConfiguration {
    #     pkgs = pkgs;
    #     modules = [./home.nix];
    #   };
    # };
    nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./nixos/configuration.nix
        ./nixos/hardware-configuration.nix
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
