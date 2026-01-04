{inputs}: final: prev: let
  nightlySrc = (inputs.neovim-nightly-overlay.packages.${prev.stdenv.hostPlatform.system}.default).overrideAttrs (old: {
    requiredSystemFeatures = [];
  });

  nvim-nightly = prev.symlinkJoin {
    name = "nvim-nightly";
    paths = [nightlySrc];
    buildInputs = [prev.makeWrapper];
    postBuild = ''
      mv $out/bin/nvim $out/bin/nvim-nightly
      if [ -d $out/share/applications ]; then
        for d in $out/share/applications/*.desktop; do
          sed -i 's/Exec=nvim/Exec=nvim-nightly/' "$d"
        done
      fi
    '';
  };
in {
  neovim-nightly = nightlySrc;
  nvim-nightly = nvim-nightly;
}
