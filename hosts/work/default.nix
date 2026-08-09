{
  config,
  pkgs,
  pkgsStable,
  ...
}: let
  homeDir = config.home.homeDirectory;
  # cinny-desktop's wrapper sets GST_PLUGIN_SYSTEM_PATH_1_0 to only the Tauri asset plugin, so WebKitGTK has zero audio decoders.
  cinnyWithCodecs = pkgs.writeShellScriptBin "cinny" ''
    export GST_PLUGIN_SYSTEM_PATH_1_0="${pkgs.lib.makeSearchPath "lib/gstreamer-1.0" (with pkgs.gst_all_1; [gstreamer.out gst-plugins-base gst-plugins-good gst-plugins-bad gst-plugins-ugly gst-libav])}''${GST_PLUGIN_SYSTEM_PATH_1_0:+:$GST_PLUGIN_SYSTEM_PATH_1_0}"
    exec ${pkgs.cinny-desktop}/bin/cinny "$@"
  '';
in {
  programs.firefox = {
    package = config.lib.nixGL.wrap pkgs.firefox;
  };

  programs.gpg = {
    enable = true;
    package = pkgs.gnupg;
  };

  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-curses;
    defaultCacheTtl = 3600;
    maxCacheTtl = 28800;
  };

  services.gnome-keyring.enable = true;

  home.packages = with pkgs; [
    (element-desktop.override {commandLineArgs = "--password-store=gnome-libsecret";})
    # _1password-cli # installed manually
    (config.lib.nixGL.wrap cinnyWithCodecs)
    pnpm
    attic-client
    blueman
    # sway # for now we will install it via apt
    # python313Packages.python-lsp-server
    (config.lib.nixGL.wrap _1password-gui)
    (config.lib.nixGL.wrap alacritty)
    (config.lib.nixGL.wrap neovide)
    (config.lib.nixGL.wrap imv)
    # (config.lib.nixGL.wrap niri)
    (config.lib.nixGL.wrap freetube)
    (config.lib.nixGL.wrap nautilus)
    (config.lib.nixGL.wrap mermaid-cli)
    (config.lib.nixGL.wrap aonsoku)
    (config.lib.nixGL.wrap localsend)
    (config.lib.nixGL.wrap proton-authenticator)
    (config.lib.nixGL.wrap brave-origin)
  ];

  # Fix FiiO LDAC: pin A2DP/LDAC codec order and drop hfp/hsp so opening a
  # mic-using app can't autoswitch the headset off the high-quality profile.
  xdg.configFile."wireplumber/wireplumber.conf.d/50-bluez.conf".text = ''
    monitor.bluez.properties = {
      bluez5.enable-sbc-xq = true
      bluez5.codecs = [ ldac aac sbc_xq sbc ]
      bluez5.roles = [ a2dp_sink a2dp_source ]
      bluez5.enable-hw-volume = true
    }
  '';

  sops = {
    defaultSopsFile = ../../secrets/work.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";

    secrets.attic_token = {};
    secrets.mlab_key = {
      path = "${config.home.homeDirectory}/.ssh/mlab_key";
      mode = "0600";
    };
    secrets.github_ssh_key = {
      sopsFile = ../../secrets/github.yaml;
      path = "${config.home.homeDirectory}/.ssh/github_ed25519";
    };
  };

  systemd.user.services.attic-watch-store = {
    Unit = {
      Description = "Attic Watch Store (Background Upload to mlab)";
      After = ["network-online.target"];
    };

    Install = {
      WantedBy = ["default.target"];
    };

    Service = {
      ExecStart = pkgs.writeShellScript "attic-watch-wrapper" ''
        TOKEN=$(${pkgs.coreutils}/bin/cat ${config.sops.secrets.attic_token.path})
        ${pkgs.attic-client}/bin/attic login mlab https://cache.marcel.cool "$TOKEN"
        exec ${pkgs.attic-client}/bin/attic watch-store mlab:system
      '';
      Restart = "always";
      RestartSec = "10s";
    };
  };

  nix.package = pkgs.nix;
  nix.distributedBuilds = true;
  nix.buildMachines = [
    {
      hostName = "ssh.marcel.cool";
      protocol = "ssh";
      systems = ["x86_64-linux"];
      sshKey = "/root/.ssh/mlab_key";
      maxJobs = 8;
      speedFactor = 2;
      supportedFeatures = ["nixos-test" "benchmark" "big-parallel" "kvm"];
    }
  ];
  nix.settings = {
    trusted-users = ["root" "mmanzanares"];
    experimental-features = ["nix-command" "flakes"];
    fallback = true;
    "builders-use-substitutes" = true;
    substituters = [
      "https://cache.marcel.cool/system"
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "system:Ve/kZ+DnW135w7Z44yIxH0kOgIXoK6akWv282O2xmWM="
    ];
  };

  # auto-accept mlab host key on first build (non-interactive); pinned after
  programs.ssh.settings."mlab".strictHostKeyChecking = "accept-new";

  home.file = let
    link = config.lib.file.mkOutOfStoreSymlink;
    clonesOwn = "${homeDir}/clones/own";
    dots = "${clonesOwn}/dots";
  in {
    ".config/kanshi/config".source = link "${dots}/.config/kanshi/config-work";
    ".cargo/env".source = link "${dots}/.cargo/env";
    ".cargo/env.fish".source = link "${dots}/.cargo/env.fish";
    ".cargo/env.nu".source = link "${dots}/.cargo/env.nu";
    ".config/hypr/devices/WS0277.conf".source =
      link "${dots}/.config/hypr/devices/WS0277.conf";
    ".config/xdg-desktop-portal/hyprland-portals.conf".source =
      link "${dots}/.config/xdg-desktop-portal/hyprland-portals.conf";
    ".mozilla/native-messaging-hosts/passff.json".source = "${pkgs.passff-host}/lib/mozilla/native-messaging-hosts/passff.json";
  };

  xdg.configFile."systemd/user/waybar.service.d/after-portal.conf".text = ''
    [Unit]
    After=xdg-desktop-portal.service
  '';
}
