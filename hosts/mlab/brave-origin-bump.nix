{
  config,
  pkgs,
  lib,
  ...
}: {
  sops.secrets."brave_origin_webhook_secret" = {
    owner = "webhook";
    mode = "0400";
  };

  services.webhook = {
    enable = true;
    ip = "127.0.0.1"; # only reachable through nginx
    port = 9000;
    urlPrefix = "_webhook";
    hooksTemplated.brave-origin = ''
      {
        "id": "brave-origin",
        "execute-command": "/run/wrappers/bin/sudo",
        "command-arguments": "-n systemctl --no-block start brave-origin-bump.service",
        "trigger-rule": {
          "match": {
            "type": "payload-hmac-sha256",
            "secret": "{{ getenv "BRAVE_ORIGIN_WEBHOOK_SECRET" }}",
            "parameter": { "source": "header", "name": "X-Gitea-Signature" }
          }
        },
        "response-message": "queued"
      }
    '';
  };

  systemd.services.webhook.serviceConfig.EnvironmentFile = [
    config.sops.secrets."brave_origin_webhook_secret".path
  ];

  security.sudo.extraRules = [
    {
      users = ["webhook"];
      commands = [
        {
          command = "/run/current-system/sw/bin/systemctl --no-block start brave-origin-bump.service";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  systemd.services.brave-origin-bump = {
    description = "Bump brave-origin-channels nightly/beta pins and push";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    environment = {
      GIT_SSH_COMMAND = "ssh -i /run/secrets/codeberg_ssh_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new";
      GIT_AUTHOR_NAME = "mlab-bot";
      GIT_AUTHOR_EMAIL = "mlab-bot@marcel.cool";
      GIT_COMMITTER_NAME = "mlab-bot";
      GIT_COMMITTER_EMAIL = "mlab-bot@marcel.cool";
      NIX_PATH = "nixpkgs=${pkgs.path}";
    };
    path = with pkgs; [nix git gnumake openssh bash];
    serviceConfig = {
      Type = "oneshot";
      User = "dev";
      StateDirectory = "brave-origin-channels";
      WorkingDirectory = "/var/lib/brave-origin-channels";
    };
    script = ''
      set -euo pipefail
      if [ -d .git ]; then
        git pull --ff-only
      else
        git clone ssh://git@codeberg.org/marcelmanz/brave-origin-channels.git .
      fi
      make release
    '';
  };

  systemd.timers.brave-origin-bump = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "03,07,15,19:00";
      Persistent = true;
    };
  };
}
