{
  description = "rff via crane (git)";
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
      rff = rust.craneLib.buildPackage {
        pname = "rff";
        version = "unstable-2025-11-03";
        src = rust.pkgs.fetchgit {
          url = "https://github.com/crabbylab/rff.git";
          rev = "d7f6a909f26439ef1c44d4a1e1241353a26c3d65";
          sha256 = "sha256-zXqXCL0pswtGnoQwE4Kmt8LSI4LIuMny3T0+o3+bmtU=";
        };
        cargoVendorHash = rust.pkgs.lib.fakeHash;
      };
    in {
      inherit rff;
      default = rff;
    };
  };
}
