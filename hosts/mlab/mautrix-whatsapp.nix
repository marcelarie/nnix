{
  config,
  lib,
  ...
}: {
  services.mautrix-whatsapp = {
    enable = true;

    settings = {
      homeserver.address = "http://localhost:8088";

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
