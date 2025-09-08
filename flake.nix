{
  description = "NixOS and Home Manager configuration";

  inputs = {
    mq.url = "github:marcelarie/mq";
    musnix.url = "github:musnix/musnix";
    neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgsStable.url = "github:NixOS/nixpkgs/nixos-25.05";
    nu-alias-converter.url = "github:marcelarie/nu-alias-converter";
    zuban.url = "path:/home/mmanzanares/clones/forks/zuban";
    # zen-browser.url = "github:0xc000022070/zen-browser-flake";
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
    tmex = {
      url = "github:marcelarie/tmex";
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
    nu-alias-converter,
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
        (final: prev: {nuit = nu-alias-converter.packages.${system}.default;})
        (final: prev: {zuban = inputs.zuban.packages.${system}.default;})
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
