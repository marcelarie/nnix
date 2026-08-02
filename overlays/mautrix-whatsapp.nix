final: prev: {
  mautrix-whatsapp = prev.mautrix-whatsapp.overrideAttrs (old: {
    src = final.fetchFromGitHub {
      owner = "marcelmanz";
      repo = "whatsapp";
      rev = "keep-deleted-messages";
      sha256 = "02njg78j7dr68g5r9xvqdrzyxzg3gpw66w944icmn4mwa9avy59w";
    };
    vendorHash = "sha256-U67qtG+J7iXq1+YApwWj1P0S9Rp0X5fMnXwiY8/8LOw=";
  });
}
