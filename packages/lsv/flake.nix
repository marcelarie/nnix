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
    rust = import ../rust/common.nix {inherit nixpkgs crane rust-overlay;};
  in {
    packages.${rust.system} = let
      lsv = rust.craneLib.buildPackage {
        pname = "lsv";
        version = "0.1.11";
        src = rust.pkgs.fetchCrate {
          pname = "lsv";
          version = "0.1.11";
          sha256 = "sha256-IJ0ug8uU/yVGd99Lvp5kCRwV6WHDC/zXg5zO0KT6Lek=";
        };
        cargoVendorHash = rust.pkgs.lib.fakeHash;
      };
    in {
      inherit lsv;
      default = lsv;
    };
  };
}
