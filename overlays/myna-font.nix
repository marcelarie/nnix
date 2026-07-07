{inputs}: final: prev: {
  # Myna: custom monospace font (github.com/sayyadirfanali/Myna).
  myna-font = prev.runCommand "myna-font" {} ''
    install -Dm644 -t $out/share/fonts/opentype ${inputs.myna}/fonts/*.otf
    install -Dm644 -t $out/share/fonts/truetype ${inputs.myna}/fonts/*.ttf
  '';
}
