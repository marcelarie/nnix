# NixOS PipeWire Audio Configuration Guide

This guide explains how to fix audio stuttering, xruns, and automatic Bluetooth switching in NixOS.

## Problem Symptoms

- Audio stuttering when switching between devices
- Fast audio dropouts when joining calls
- Audio stops working when changing settings in pavucontrol
- Bluetooth devices don't auto-switch when connected
- Constant xrun errors in PipeWire logs

## Root Causes Found

1. **musnix enabled** - Causes conflicts with desktop audio usage
2. **Small buffer sizes** - 128 samples too small for stable desktop use  
3. **combine-stream module** - Creates conflicts during device switching
4. **Missing Bluetooth auto-switching** - No priority configuration for BT devices

## NixOS Configuration Fix

Add this to your `configuration.nix`:

```nix
{
  # Disable PulseAudio in favor of PipeWire
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
    
    # Custom PipeWire configuration for stability
    extraConfig.pipewire = {
      "99-custom-config" = {
        "context.properties" = {
          # Larger buffers to prevent xruns and stuttering
          "default.clock.rate" = 48000;
          "default.clock.quantum" = 1024;
          "default.clock.min-quantum" = 32;
          "default.clock.max-quantum" = 2048;
          
          # CPU optimization
          "default.clock.power-of-two-quantum" = true;
          
          # Memory settings
          "mem.warn-mlock" = false;
          "mem.allow-mlock" = true;
        };
      };
    };
    
    # Better JACK buffer size for desktop use
    extraConfig.jack = {
      "99-buffer-size" = {
        "jack.properties" = {
          "default.buffer-size" = 1024;  # Increased from 128
        };
      };
    };
    
    # PulseAudio compatibility layer config
    extraConfig.pipewire-pulse = {
      "99-pulse-config" = {
        "pulse.properties" = {
          "pulse.min.req" = "1024/48000";
          "pulse.default.req" = "2048/48000";
          "pulse.max.req" = "4096/48000";
          "pulse.min.frag" = "1024/48000";
          "pulse.default.frag" = "2048/48000"; 
          "pulse.max.frag" = "4096/48000";
          "pulse.default.tlength" = "4096/48000";
          "pulse.min.quantum" = "1024/48000";
          "pulse.max.quantum" = "2048/48000";
        };
        "stream.properties" = {
          "node.latency" = "1024/48000";
          "resample.quality" = 4;
        };
      };
    };
  };

  # IMPORTANT: Disable musnix if you have it enabled
  # musnix.enable = false;  # Comment this out or set to false
  
  # Audio performance limits
  security.pam.loginLimits = [
    { domain = "@audio"; item = "rtprio"; type = "-"; value = "95"; }
    { domain = "@audio"; item = "memlock"; type = "-"; value = "unlimited"; }
    { domain = "mmanzanares"; item = "rtprio"; type = "-"; value = "95"; }
    { domain = "mmanzanares"; item = "memlock"; type = "-"; value = "unlimited"; }
  ];
  
  # Bluetooth configuration
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings = {
      General = {
        Experimental = true;
        AutoEnable = true;
      };
    };
  };
}
```

## WirePlumber Configuration for Bluetooth Auto-Switching

Create these files through home-manager or put them in `/etc/wireplumber/`:

### 1. ALSA Device Optimization (`99-alsa-config.conf`)

```lua
-- ALSA device configuration to reduce xruns and improve stability

alsa_monitor.properties = {
  ["alsa.period-size"] = 1024,
  ["alsa.periods"] = 2,
  ["alsa.use-acp"] = false,
  ["alsa.use-ucm"] = true,
  ["audio.format"] = "S32LE",
  ["audio.rate"] = 48000,
}

alsa_monitor.rules = {
  {
    matches = {
      { { "device.bus", "equals", "pci" } },
    },
    apply_properties = {
      ["api.alsa.period-size"] = 1024,
      ["api.alsa.periods"] = 2,
      ["api.alsa.headroom"] = 8192,
      ["api.alsa.disable-mmap"] = false,
      ["api.alsa.disable-batch"] = false,
      ["session.suspend-timeout-seconds"] = 5,
    },
  },
  
  {
    matches = {
      { { "device.name", "matches", "*skl_hda_dsp*" } },
    },
    apply_properties = {
      ["device.description"] = "Intel Audio",
      ["api.alsa.use-chmap"] = false,
      ["node.pause-on-idle"] = false,
    },
  },
}
```

### 2. Bluetooth Auto-Switching (`99-bluetooth-auto-switch.conf`)

```lua
-- Bluetooth device configuration
table.insert(bluez_monitor.rules, {
  matches = {
    { { "device.name", "matches", "bluez_card.*" } },
  },
  apply_properties = {
    ["bluez5.auto-connect"] = "[ a2dp_sink hsp_hs hfp_hf ]",
    ["bluez5.hw-volume"] = "[ a2dp_sink hsp_hs hfp_hf ]",
    ["device.profile"] = "a2dp-sink",
    ["device.description"] = "Bluetooth Audio Device",
  },
})

-- High priority for Bluetooth audio nodes
table.insert(bluez_monitor.rules, {
  matches = {
    { { "node.name", "matches", "bluez_output.*" } },
  },
  apply_properties = {
    ["priority.session"] = 2000,
    ["node.description"] = "Bluetooth Speaker",
    ["media.class"] = "Audio/Sink",
    ["node.pause-on-idle"] = false,
  },
})
```

### 3. Disable Combine Stream (`99-disable-combine-stream.conf`)

```lua
-- Disable problematic combine stream modules
table.insert(alsa_monitor.rules, {
  matches = {
    { { "node.name", "matches", "alsa_output.*" } },
  },
  apply_properties = {
    ["session.suspend-timeout-seconds"] = 0,
    ["node.pause-on-idle"] = false,
  },
})
```

## Adding Through Home-Manager

If using home-manager, add these configurations:

```nix
{
  # In your home.nix
  home.file = {
    ".config/wireplumber/wireplumber.conf.d/99-alsa-config.conf".text = ''
      # (content from above)
    '';
    
    ".config/wireplumber/wireplumber.conf.d/99-bluetooth-auto-switch.conf".text = ''
      # (content from above)  
    '';
    
    ".config/wireplumber/wireplumber.conf.d/99-disable-combine-stream.conf".text = ''
      # (content from above)
    '';
    
    ".config/pipewire/pipewire.conf.d/99-custom-config.conf".text = ''
      context.properties = {
        default.clock.rate = 48000
        default.clock.quantum = 1024
        default.clock.min-quantum = 32
        default.clock.max-quantum = 2048
        default.clock.power-of-two-quantum = true
        mem.warn-mlock = false
        mem.allow-mlock = true
      }
    '';
  };
}
```

## Audio Switching Script

Add this script to your system packages:

```nix
environment.systemPackages = with pkgs; [
  (writeShellScriptBin "audio-switch" ''
    #!/bin/bash
    case "$1" in
        "hdmi")
            pactl set-default-sink alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__HDMI1__sink
            echo "Switched to HDMI output"
            ;;
        "headphones") 
            pactl set-default-sink alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__Headphones__sink
            echo "Switched to headphones output"
            ;;
        "bluetooth")
            BT_SINK=$(pactl list short sinks | grep bluez | head -1 | cut -f2)
            if [ -n "$BT_SINK" ]; then
                pactl set-default-sink "$BT_SINK"
                echo "Switched to Bluetooth: $BT_SINK"
            else
                echo "No Bluetooth audio device found"
                exit 1
            fi
            ;;
        "auto")
            BT_SINK=$(pactl list short sinks | grep bluez | grep -v SUSPENDED | head -1 | cut -f2)
            if [ -n "$BT_SINK" ]; then
                pactl set-default-sink "$BT_SINK"
                echo "Auto-switched to Bluetooth: $BT_SINK"
            else
                pactl set-default-sink alsa_output.pci-0000_00_1f.3-platform-skl_hda_dsp_generic.HiFi__HDMI1__sink
                echo "Auto-switched to HDMI"
            fi
            ;;
        "list")
            echo "Available audio outputs:"
            pactl list short sinks
            echo "Current default:"
            pactl info | grep "Default Sink"
            ;;
        *)
            echo "Usage: audio-switch [hdmi|headphones|bluetooth|list|auto]"
            pactl info | grep "Default Sink"
            ;;
    esac
    
    # Move streams to new sink
    if [[ "$1" =~ ^(hdmi|headphones|bluetooth|auto)$ ]]; then
        pactl list short sink-inputs | while read stream; do
            streamId=$(echo $stream | cut '-d ' -f1)
            pactl move-sink-input "$streamId" @DEFAULT_SINK@ 2>/dev/null
        done
    fi
  '')
];
```

## Automatic Bluetooth Monitor Service (Home-Manager)

```nix
{
  systemd.user.services.bluetooth-audio-monitor = {
    Unit = {
      Description = "Bluetooth Audio Auto-Switch Monitor";
      After = [ "pipewire.service" "bluetooth.service" ];
      Wants = [ "bluetooth.service" ];
    };
    
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.writeShellScript "bluetooth-monitor" ''
        # Monitor script content here
      ''}";
      Restart = "always";
      RestartSec = 3;
    };
    
    Install.WantedBy = [ "default.target" ];
  };
}
```

## Key Differences from Ubuntu Setup

1. **System-level configs** go in `configuration.nix` instead of `/etc/`
2. **User configs** can be managed through home-manager `home.file`  
3. **Scripts** can be added as `writeShellScriptBin` packages
4. **Services** use `systemd.user.services` in home-manager
5. **Security limits** use `security.pam.loginLimits` instead of `/etc/security/limits.d/`

## Testing

After applying these changes:

1. `sudo nixos-rebuild switch` (for system config)
2. `home-manager switch` (for user config)  
3. `systemctl --user restart pipewire pipewire-pulse wireplumber`
4. Test with `audio-switch list` and connect Bluetooth devices

## Troubleshooting

- Check service status: `systemctl --user status pipewire wireplumber`
- View logs: `journalctl --user -u pipewire -u wireplumber -f`
- Test switching: `audio-switch auto`
- Check for xruns: `journalctl --user -u pipewire | grep xrun`