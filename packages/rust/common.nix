{ nixpkgs, crane, rust-overlay }:
let
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
  inherit system pkgs toolchain craneLib;
}
