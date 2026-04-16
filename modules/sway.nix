{
  config,
  lib,
  pkgs,
  ...
}:
let
  homeDir = config.home.homeDirectory;
  modifier = "Mod4";

  chromeExe = "${pkgs.google-chrome}/bin/google-chrome-stable";
  cursorExe = "/usr/share/cursor/cursor";
  edge = "/opt/microsoft/msedge/microsoft-edge";
  flameshotExe = lib.getExe pkgs.flameshot;
  lightExe = lib.getExe pkgs.light;
  menu = "${lib.getExe pkgs.rofi} -show run | xargs swaymsg exec --";
  pactlExe = "${pkgs.pulseaudio}/bin/pactl";
  swaylockExe = lib.getExe pkgs.swaylock-effects;
  term = lib.getExe pkgs.alacritty;
in
{
  programs.alacritty = {
    enable = true;
    settings.window.padding = {
      x = 10;
      y = 10;
    };
  };

  home.packages = with pkgs; [
    flameshot
    gnome-keyring
    google-chrome
    light
    networkmanagerapplet
    pulseaudio
    rofi
    swaylock-effects
    vscode
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

  # Waybar exits on startup without ~/.config/waybar/config; this generates it.
  # systemd.enable stays false so Sway remains the process that spawns waybar (see bars below).
  programs.waybar = {
    enable = true;
    systemd.enable = false;
    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 34;
      modules-left = [
        "sway/workspaces"
        "sway/mode"
      ];
      modules-center = [ "sway/window" ];
      modules-right = [ "clock" ];
      "sway/workspaces" = {
        disable-scroll = true;
        all-outputs = true;
      };
      "sway/window".max-length = 60;
      "clock".format = "{:%Y-%m-%d %H:%M}";
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
        { command = "${homeDir}/scripts/setmon"; always = false; }
        { command = "${pkgs.networkmanagerapplet}/bin/nm-applet"; always = false; }
        { command = "${homeDir}/scripts/sway-startup.sh"; always = false; }
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
    };
  };
}
