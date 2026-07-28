{pkgs, ...}: {
  systemd.services.brave-origin-bump = {
    description = "Bump brave-origin-channels nightly/beta pins and push";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    environment = {
      GIT_SSH_COMMAND = "ssh -i /run/secrets/codeberg_ssh_key -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new";
      GIT_AUTHOR_NAME = "mlab-bot";
      GIT_AUTHOR_EMAIL = "mlab@localhost";
      GIT_COMMITTER_NAME = "mlab-bot";
      GIT_COMMITTER_EMAIL = "mlab@localhost";
    };
    path = with pkgs; [nix git gnumake openssh bash curl jq nix-prefetch nix-hash];
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
