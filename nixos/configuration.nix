{
  config,
  pkgs,
  ...
}: {
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  # boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.loader.efi.canTouchEfiVariables = true;
  nix.settings = {
    auto-optimise-store = true;
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    warn-dirty = false;
    substituters = [
      "https://hyprland.cachix.org"
      "https://marcelarie.cachix.org"
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
      "marcelarie.cachix.org-1:loFQMIgWqiIgfRixHOrEwbGADvFYu8RJXF6jqL0HUy8="
    ];
    trusted-users = ["root" "marcel"];
  };

  # TODO: Learn how to setup cachix auto push
  # Option 1:
  services.cachix-agent.enable = true;
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

  networking.hostName = "nixos";

  hardware = {
    bluetooth = {
      enable = true;
      powerOnBoot = true;
      settings.General.Experimental = true;
    };
  };
  services.mullvad-vpn.enable = true;
  services.flatpak.enable = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

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

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
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
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

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
    extraGroups = ["networkmanager" "wheel"];
    packages = with pkgs; [
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
    defaultSession = "hyprland";
    autoLogin = {
      enable = false;
      user = "marcel";
    };
  };

  # Install firefox.
  programs.firefox = {
    enable = true;

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
      };
    };
  };

  environment.systemPackages = with pkgs; [
    vim
    neovim
    wget
    mullvad-vpn
    mullvad
    git
    gnumake
    usbutils
    networkmanagerapplet
    glib
    gcc
    gnupg
    cachix
    openssl
    (pkgs.writeTextDir "share/sddm/themes/breeze/theme.conf.user" ''
      [General]
      background=/etc/sddm/black.png
    '')
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "24.11"; # Did you read the comment?
}
