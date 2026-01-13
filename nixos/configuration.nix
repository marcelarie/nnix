{ config, pkgs, ... }: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  # boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.loader.efi.canTouchEfiVariables = true;
  nix.settings = {
    max-jobs = "auto";
    # cores = 0; # Use all cores
    keep-outputs = true;
    keep-derivations = true;
    auto-optimise-store = true;
    experimental-features = [ "nix-command" "flakes" ];
    warn-dirty = false;
    substituters = [
      "https://nix-community.cachix.org"
      # "https://hyprland.cachix.org"
      # "https://marcelarie.cachix.org"
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2QlZceJ1306tMKZnQAS4p75VYwtwHf1qkw="
      # "marcelarie.cachix.org-1:loFQMIgWqiIgfRixHOrEwbGADvFYu8RJXF6jqL0HUy8="
    ];
    trusted-users = [ "root" "marcel" ];
    connect-timeout = 15;
  };

  # TODO: Learn how to setup cachix auto push
  # Option 1:
  # services.cachix-agent.enable = true;
  # services.cachix-agent = {
  #   enable = true;
  #   cache = "marcelarie";
  # };
  # Option 2:
  # services.cachix‑watch‑store = {
  #   enable           = true;
  #   cacheName        = "marcelarie";
  #   cachixTokenFile  = "/home/marcel/.config/cachix/cachix.dhall";
  #   # optional settings:
  #   # compressionLevel = 3;
  #   # jobs             = 4;
  #   # host             = "https://marcelarie.cachix.org";  # rarely needed
  #   # verbose          = true;
  # };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  networking.hostName = "nixos";
  services.fwupd.enable = true;

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings = { General = { ReconnectAttempts = "0"; }; };
    };
  };
  services.mullvad-vpn.enable = true;
  services.flatpak.enable = true;

  # Enable Docker
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;
  networking.networkmanager.plugins = with pkgs; [ networkmanager-openvpn ];
  # networking.enableIPv6 = false;

  # Set your time zone.
  time.timeZone = "Europe/Madrid";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  # services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.desktopManager.plasma6.enable = true;
  programs.hyprland.enable = true;
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ ];

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
  services.nzbget = { enable = true; };

  services.ollama = { enable = true; };

  systemd.services.ollama.environment = {
    OLLAMA_CONTEXT_LENGTH = "32768";
    OLLAMA_FLASH_ATTENTION = "1";
    OLLAMA_KEEP_ALIVE = "24h";
  };

  services.open-webui = {
    enable = true;
    port = 8080;
  };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };
  # services.udev.packages = [pkgs.mixxx];
  musnix.enable = false;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  security = {
    # If enabled, pam_wallet will attempt to automatically unlock the user’s default KDE wallet upon login.
    # If the user has no wallet named “kdewallet”, or the login password does not match their wallet password,
    # KDE will prompt separately after login.
    pam = {
      services = {
        marcel = {
          kwallet = {
            enable = true;
            package = pkgs.kdePackages.kwallet-pam;
          };
        };
      };
    };
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.marcel = {
    isNormalUser = true;
    description = "marcel";
    extraGroups = [ "networkmanager" "wheel" "audio" "docker" ];
    packages = with pkgs;
      [
        kitty
        # kdePackages.kate
        #  thunderbird
      ];
  };

  services.displayManager = {
    sddm = {
      enable = true;
      wayland.enable = true;
      theme = "breeze";
    };
    sessionPackages = [ pkgs.hyprland pkgs.niri ];
    defaultSession = "hyprland";
    autoLogin = {
      enable = false;
      user = "marcel";
    };
  };

  programs.firefox = {
    enable = true;
    nativeMessagingHosts.packages = [ pkgs.passff-host ];

    policies = {
      Preferences = {
        "extensions.pocket.enabled" = {
          Value = false;
          Status = "locked";
        };
        "ui.key.menuAccessKeyFocuses" = {
          Value = false;
          Status = "locked";
        };
        "browser.tabs.allowTabDetach" = {
          Value = false;
          Status = "locked";
        };
        "alerts.useSystemBackend" = {
          Value = true;
          Status = "locked";
        };
      };
    };
  };

  environment.systemPackages = with pkgs; [
    vim
    neovim
    wget
    # mullvad-vpn
    # mullvad
    git
    gnumake
    usbutils
    networkmanagerapplet
    glib
    gcc
    gnupg
    pass
    openssl
    openvpn
    sbc
    chromium
    (pkgs.writeTextDir "share/sddm/themes/breeze/theme.conf.user" ''
      [General]
      background=/etc/sddm/black.png
    '')
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pkgs.pinentry-curses;
  };

  sops = {
    defaultSopsFile = ../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    gnupg.home = "/home/marcel/.gnupg";
    secrets.example_secret = { owner = "marcel"; };
  };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = false;
  networking.networkmanager.wifi.powersave = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
