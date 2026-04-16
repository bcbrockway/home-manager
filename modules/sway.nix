{
  config,
  lib,
  pkgs,
  latest,
  ...
}:
let
  modifier = "Mod4";

  chromeExe = "${pkgs.google-chrome}/bin/google-chrome-stable";
  cursorExe = "/usr/share/cursor/cursor";
  edge = "${pkgs.microsoft-edge}/bin/microsoft-edge";
  # edge = "/opt/microsoft/msedge/microsoft-edge";
  flameshotExe = lib.getExe pkgs.flameshot;
  lightExe = lib.getExe pkgs.light;
  menu = "${lib.getExe pkgs.rofi} -show run | xargs swaymsg exec --";
  pactlExe = "${pkgs.pulseaudio}/bin/pactl";
  swaylockExe = lib.getExe pkgs.swaylock-effects;
  term = lib.getExe pkgs.alacritty;

  dbusUpdateEnv = "${pkgs.dbus}/bin/dbus-update-activation-environment";
  systemctlExe = "${pkgs.systemd}/bin/systemctl";
  # One shell so each step finishes before the next (Sway does not wait between separate `exec` lines).
  swayAudioPortalInit =
    "${lib.getExe pkgs.bash} -c ${
      lib.escapeShellArg (
        "${dbusUpdateEnv} --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway && "
        + "${systemctlExe} --user stop pipewire wireplumber xdg-desktop-portal xdg-desktop-portal-wlr && "
        + "${systemctlExe} --user start wireplumber xdg-desktop-portal"
      )
    }";
in
{
  # Sway (no full GNOME session): GTK + fontconfig defaults so Chromium/Edge use Ubuntu-like UI
  # fonts instead of heavy fallbacks. GNOME sessions keep their own dconf fonts; this only
  # affects the Home Manager profile that imports this module.
  gtk.enable = true;
  gtk.font = {
    package = pkgs.ubuntu-classic;
    name = "Ubuntu";
    size = 11;
  };

  fonts.fontconfig.enable = true;
  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "Ubuntu" "Cantarell" "DejaVu Sans" ];
    serif = [ "Ubuntu" "DejaVu Serif" ];
    monospace = [ "Ubuntu Mono" "DejaVu Sans Mono" ];
    emoji = [ "Noto Color Emoji" ];
  };

  home.packages = with pkgs; [
    flameshot
    gnome-keyring
    latest.google-chrome
    latest.microsoft-edge
    light
    networkmanagerapplet
    pulseaudio
    rofi
    swaylock-effects
    vscode
    cantarell-fonts
    noto-fonts-color-emoji
  ];

  # Chromium does not treat sway as a GNOME-style session, so it will not pick the GNOME
  # password store by itself; `password-store` below forces that. A Secret Service still has
  # to be running (see extraSessionCommands): without gnome-keyring-daemon, there is nothing to talk to.
  # https://github.com/microsoft/vscode/issues/187338
  home.file.".cursor/argv.json".text = builtins.toJSON {
    "enable-crash-reporter" = true;
    "crash-reporter-id" = "48ce64db-5065-4bf3-859d-614652434d83";
    "password-store" = "gnome";
  };

  programs.alacritty = {
    enable = true;
    settings.window.padding = {
      x = 10;
      y = 10;
    };
  };

  programs.waybar = {
    enable = true;
    systemd.enable = false;
    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: Ubuntu, sans-serif;
        font-size: 14px;
        min-height: 0;
      }

      window#waybar {
        background: #242424;
        color: white;
      }

      tooltip {
        background: rgba(43, 48, 59, 0.5);
        border: 1px solid rgba(100, 114, 125, 0.5);
      }
      tooltip label {
        color: white;
      }

      #workspaces button {
        padding: 0 5px;
        background: transparent;
        color: white;
      }

      #workspaces button.focused {
        background: #64727D;
      }

      #mode, #clock, #battery {
        padding: 0 10px;
      }

      #mode {
        background: #64727D;
      }

      #clock {
        background-color: #242424;
      }

      #battery {
        background-color: #ffffff;
        color: black;
      }

      #battery.charging {
        color: white;
        background-color: #26A65B;
      }

      #tray {
        background-color: #242424;
        padding-right: 10px;
      }

      @keyframes blink {
        to {
          background-color: #ffffff;
          color: black;
        }
      }

      #battery.warning:not(.charging) {
        background: #f53c3c;
        color: white;
        animation-name: blink;
        animation-duration: 0.5s;
        animation-timing-function: steps(12);
        animation-iteration-count: infinite;
        animation-direction: alternate;
      }
    '';
    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 32;
      modules-left = [
        "sway/workspaces"
        "sway/mode"
      ];
      modules-center = [ "clock" ];
      modules-right = [ "tray" ];
      "sway/workspaces" = {
        disable-scroll = true;
      };
      "clock".format = "{:%d/%m/%Y %H:%M}";
      "tray" = {
        "icon-size" = 16;
        spacing = 10;
      };
    };
  };

  services.kanshi = {
    enable = true;
  };

  wayland.windowManager.sway = {
    enable = true;
    checkConfig = false;
    wrapperFeatures.gtk = true;

    # Libvirt/QEMU + virtio-gpu (and sometimes other virtual DRM) can fail to
    # deliver vblank/page-flip events; the session then only redraws when the
    # cursor moves. These wlroots toggles avoid the worst of that in guests.
    extraSessionCommands = ''
      export WLR_DRM_NO_ATOMIC=1
      export WLR_NO_HARDWARE_CURSORS=1
      # Start GNOME Keyring's Secret Service on the session D-Bus (org.freedesktop.secrets).
      # GNOME starts this automatically; Sway does not. Needed for libsecret and for Chromium
      # when using password-store=gnome (see ~/.cursor/argv.json above).
      eval $(${pkgs.gnome-keyring}/bin/gnome-keyring-daemon --start --components=secrets)
    '';

    extraConfigEarly = ''
      set $chromeSettings "--enable-features=UseOzonePlatform --ozone-platform=wayland"
    '';

    config = {
      inherit modifier;
      terminal = term;
      menu = menu;

      window = {
        titlebar = false;
        border = 2;
      };
      floating = {
        titlebar = false;
        border = 2;
      };

      gaps = {
        inner = 10;
        outer = 0;
      };

      focus.followMouse = "yes";

      input = {
        "type:touchpad".natural_scroll = "enabled";
        "type:keyboard".xkb_layout = "gb";
      };

      # output."*" = {
      #   bg = "~/wallpaper/dolomites.jpg fill";
      # };

      startup = [
        { command = "${pkgs.networkmanagerapplet}/bin/nm-applet"; always = false; }
        { command = swayAudioPortalInit; always = false; }
        # Sway reload drops runtime output layout; kanshi keeps the same profile pointer and
        # will not re-apply (https://github.com/emersion/kanshi/issues/43). Restart the user unit.
        { command = "${pkgs.systemd}/bin/systemctl --user restart kanshi.service"; always = true; }
      ];

      bars = [
        { command = "${lib.getExe pkgs.waybar}"; }
      ];

      window.commands = [
        {
          criteria = { app_id = "Alacritty"; };
          command = "opacity 0.9";
        }
        {
          criteria = { app_id = "^chrome-.*"; };
          command = "shortcuts_inhibitor disable";
        }
        {
          criteria = { class = "Code"; };
          command = "opacity 0.9";
        }
        {
          criteria = { app_id = "Rofi"; };
          command = "opacity 0.9";
        }
        {
          criteria = { class = "Spotify"; };
          command = "opacity 0.9";
        }
        {
          criteria = { class = "mail.google.com__chat_u_0"; };
          command = "opacity 0.9";
        }
        {
          criteria = {
            app_id = "zoom";
            title = "Settings";
          };
          command = "floating enable, floating_maximum_size 1000 x 800";
        }
      ];

      keybindings = lib.mkOptionDefault {
        "${modifier}+Shift+c" = "exec ${cursorExe}";
        "${modifier}+Shift+e" = "exec swaynag -t warning -m 'You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session.' -B 'Yes, exit sway' 'swaymsg exit'";
        "${modifier}+Shift+f" = "exec ${edge} --profile-directory=Default --app-id=ompifgpmddkgmclendfeacglnodjjndh --app-url=https://teams.cloud.microsoft/?clientType=pwa";
        "${modifier}+Shift+p" = "exec ${chromeExe}";
        "${modifier}+Shift+r" = "reload";
        "${modifier}+Shift+t" = "exec ${edge} --profile-directory=Default --app-id=dlgohinmglaoopaiplliaecdpmnepmga --app-url=https://app.todoist.com/app";
        "${modifier}+Shift+w" = "exec ${edge} --profile-directory=Default";
        "${modifier}+Shift+x" = "exec ${swaylockExe} --screenshots --effect-blur 5x3";

        "${modifier}+Control+Left" = "move workspace to output left";
        "${modifier}+Control+Down" = "move workspace to output down";
        "${modifier}+Control+Up" = "move workspace to output up";
        "${modifier}+Control+Right" = "move workspace to output right";

        "${modifier}+f" = "fullscreen";


        Print = "exec ${flameshotExe} gui";
        XF86AudioMute = "exec --no-startup-id ${pactlExe} set-sink-mute 0 toggle";
        XF86AudioLowerVolume = "exec --no-startup-id ${pactlExe} set-sink-volume 0 -5%";
        XF86AudioRaiseVolume = "exec --no-startup-id ${pactlExe} set-sink-volume 0 +5%";
        XF86MonBrightnessDown = "exec --no-startup-id ${lightExe} -U 5";
        XF86MonBrightnessUp = "exec --no-startup-id ${lightExe} -A 5";
      };

      workspaceOutputAssign = [
        {output = "DP-4"; workspace = "1";}
        {output = "DP-4"; workspace = "2";}
        {output = "DP-4"; workspace = "3";}
        {output = "DP-6"; workspace = "4";}
        {output = "DP-6"; workspace = "5";}
        {output = "DP-6"; workspace = "6";}
        {output = "DP-6"; workspace = "7";}
        {output = "DP-6"; workspace = "8";}
        {output = "DP-6"; workspace = "9";}
        {output = "DP-6"; workspace = "0";}
      ];
    };
  };
}
