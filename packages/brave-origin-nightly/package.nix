{pkgs}: let
  release = import ./release.nix;
in
  pkgs.callPackage ./make-brave.nix {} release
