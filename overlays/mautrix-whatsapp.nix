final: prev: {
  # ponytail: when a contact "deletes for everyone", keep the original
  # message/file in Matrix and post an m.notice instead of redacting.
  # "Delete for me" (your own deletes) is left at stock behavior (redacts).
  # Patch is pinned to v0.2607.0 line numbers; a nixpkgs bump that moves the
  # code will fail to apply loudly — re-fix then.
  mautrix-whatsapp = prev.mautrix-whatsapp.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./mautrix-whatsapp-keep-deleted-messages.patch
    ];
  });
}
