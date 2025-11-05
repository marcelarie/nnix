{
  description = "pulseaudio-next-output via crane (git)";
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
      pulseaudio-next-output = rust.craneLib.buildPackage {
        pname = "pulseaudio-next-output";
        version = "unstable-2025-09-04";
        nativeBuildInputs = with rust.pkgs; [pkg-config];
        buildInputs = with rust.pkgs; [pulseaudio];
        src = rust.pkgs.fetchgit {
          url = "https://github.com/murlakatamenka/pulseaudio-next-output";
          rev = "e46ea275e17ec7e00edd1c9627f00c4b7134b012";
          sha256 = "sha256-GuZCop5hUWeBqEYQB3O+MnQVg3uve3pC4ZjLejDflUc=";
        };
        cargoVendorHash = "sha256-aWw3qZFizCIoYN8M0cpVkA1misOezHmGi/UxM+7/6Ok=";
      };
    in {
      inherit pulseaudio-next-output;
      default = pulseaudio-next-output;
    };
  };
}
