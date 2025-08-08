{
  pkgs,
  ...
}: let
  terminalPackages = import ./terminal-packages.nix { inherit pkgs; };
in {
  environment.packages = terminalPackages;
  
  environment.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
    OPENSSL_DIR = "${pkgs.openssl.out}";
    OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
    OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";
  };
  
  user.shell = "${pkgs.fish}/bin/fish";
}