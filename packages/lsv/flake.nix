{
  description = "lsv via crane (crates.io)";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.crane.url = "github:ipetkov/crane";
  inputs.rust-overlay.url = "github:oxalica/rust-overlay";

  outputs = {
    self,
    nixpkgs,
    crane,
    rust-overlay,
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [rust-overlay.overlays.default];
    };
    toolchain = pkgs.rust-bin.stable."1.90.0".default.override {
      targets = [pkgs.stdenv.hostPlatform.config];
    };
    craneLib = (crane.mkLib pkgs).overrideToolchain toolchain;
  in {
    packages.${system} = let
      lsv = craneLib.buildPackage {
        pname = "lsv";
        version = "0.1.11";
        src = pkgs.fetchCrate {
          pname = "lsv";
          version = "0.1.11";
          sha256 = "sha256-IJ0ug8uU/yVGd99Lvp5kCRwV6WHDC/zXg5zO0KT6Lek=";
        };
        cargoVendorHash = pkgs.lib.fakeHash;
      };
    in {
      inherit lsv;
      default = lsv;
    };
  };
}
