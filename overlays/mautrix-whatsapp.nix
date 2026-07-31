final: prev: {
  # ponytail: patch mautrix-whatsapp so remote deletes ("delete for everyone"
  # and "delete for me") no longer redact messages out of Matrix rooms.
  # Patch is pinned to v0.2607.0 line numbers; a nixpkgs bump that moves the
  # code will fail to apply loudly — re-fix then.
  mautrix-whatsapp = prev.mautrix-whatsapp.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./mautrix-whatsapp-keep-deleted-messages.patch
    ];
  });
}
