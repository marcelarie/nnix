{
  description = "audio-select via crane (git)";
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
      rev = "ecbd5e8a5ad073e79c5a7ffe017d9a73de3dcfa4";
      audioSelect = rust.craneLib.buildPackage {
        pname = "audio-select";
        version = "unstable-${builtins.substring 0 7 rev}";
        src = rust.pkgs.fetchgit {
          url = "https://github.com/sudosteve/audio-select.git";
          inherit rev;
          sha256 = "sha256-X3rfil0dAVvEHgRcL4BGdqH5qLo/VS74UB5fEH6m0jE=";
        };
        cargoVendorHash = rust.pkgs.lib.fakeHash;
        nativeBuildInputs = with rust.pkgs; [pkg-config wrapGAppsHook3];
        buildInputs = with rust.pkgs; [
          atk
          cairo
          gdk-pixbuf
          glib
          gtk3
          libpulseaudio
          pango
        ];
      };
    in {
      inherit audioSelect;
      default = audioSelect;
    };
  };
}
