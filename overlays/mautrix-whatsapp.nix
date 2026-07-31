final: prev: {
  mautrix-whatsapp = prev.mautrix-whatsapp.overrideAttrs (old: {
    src = final.fetchFromGitHub {
      owner = "marcelmanz";
      repo = "whatsapp";
      rev = "keep-deleted-messages";
      sha256 = "sha256-bvnp95Pz2UPZt2tPRWRAPdeNTk9tKo2YVd2YSwuAC/Q=";
    };
    vendorHash = "sha256-U67qtG+J7iXq1+YApwWj1P0S9Rp0X5fMnXwiY8/8LOw=";
  });
}
