final: prev: {
  mautrix-whatsapp = prev.mautrix-whatsapp.overrideAttrs (old: {
    src = final.fetchFromGitHub {
      owner = "marcelmanz";
      repo = "whatsapp";
      rev = "keep-deleted-messages";
      hash = final.lib.fakeSha; # build once, paste the got hash, rebuild
    };
  });
}
