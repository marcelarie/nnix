{
  config,
  lib,
  ...
}: {
  services.mautrix-whatsapp = {
    enable = true;

    settings = {
      homeserver.address = "http://localhost:8088";

      network = {
        history_sync = {
          request_full_sync = true; # bump sync window from 3 months to 1 year
          max_initial_conversations = -1; # -1 = create portals for every conversation
        };
        disable_view_once = true; # keep view-once media instead of deleting after view
      };

      bridge = {
        # single-user bridge.
        relay.enabled = false;

        permissions."@admin:marcel.cool" = "admin";
      };
      encryption = {
        allow = true;
        default = true;
        require = true;
        pickle_key = "$ENCRYPTION_PICKLE_KEY"; # substituted from environmentFile
      };
    };

    environmentFile = config.sops.templates."mautrix-whatsapp.env".path;
  };
}
