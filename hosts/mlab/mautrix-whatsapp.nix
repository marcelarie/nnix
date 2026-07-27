{
  config,
  lib,
  ...
}: {
  services.mautrix-whatsapp = {
    enable = true;

    settings = {
      # Your Synapse client listener is 127.0.0.1:8088, not the module default :8448.
      # (domain is auto-filled from services.matrix-synapse.settings.server_name.)
      homeserver.address = "http://localhost:8088";

      # Default permissions."*" = "relay" leaves you relay-only on your own
      # homeserver; bump your domain to admin so you can puppet your WA identity.
      bridge.permissions = {
        "*" = "relay";
        "marcel.cool" = "admin";
      };
    };

    # ponytail: encryption off by default — portal rooms are plain Matrix rooms
    # on your single-user homeserver. To E2E the Cinny<->bridge leg, set:
    #   environmentFile = config.sops.secrets."mautrix_whatsapp_env".path;
    #   settings.encryption = { allow = true; default = true; require = true;
    #     pickle_key = "$ENCRYPTION_PICKLE_KEY"; };
    # and add ENCRYPTION_PICKLE_KEY=<rand> to secrets/mlab.yaml.
  };
}
