{ config
, lib
, pkgs
, latest
, ...
}:
let
  modifier = "Mod4";

  bluemanAppletExe = lib.getExe' pkgs.blueman "blueman-applet";
  bluemanManagerExe = lib.getExe' pkgs.blueman "blueman-manager";
  chromeExe = lib.getExe latest.google-chrome;
  dbusUpdateEnvExe = lib.getExe' pkgs.dbus "dbus-update-activation-environment";
  edgeExe = lib.getExe latest.microsoft-edge;
  gnomeKeyringDaemonExe = lib.getExe' pkgs.gnome-keyring "gnome-keyring-daemon";
  lightExe = lib.getExe pkgs.light;
  nmAppletExe = lib.getExe' pkgs.networkmanagerapplet "nm-applet";
  pactlExe = lib.getExe' pkgs.pulseaudio "pactl";
  # Nix-built swaylock links nixpkgs libpam, which resolves PAM modules under the
  # nix store — Ubuntu's common-* reference pam_sss, pam_systemd, etc. in
  # /usr/lib/.../security/, so unlock breaks even after fixing @include in
  # /etc/pam.d/swaylock.  On HM genericLinux (Ubuntu + nix), use the OS binary.
  swaylockHost = config.targets.genericLinux.enable;
  swaylockExe =
    if swaylockHost then "/usr/bin/swaylock" else lib.getExe pkgs.swaylock-effects;
  # Ubuntu ships swaylock (universe), not swaylock-effects — no --screenshots / --effect-blur.
  # Stock default is a very light fill; match Waybar-ish dark and keep the ring visible when idle.
  swaylockArgs =
    if swaylockHost then
      lib.concatStringsSep " " [
        "--color 242424ff"
        "--indicator-idle-visible"
        "--ring-color b4b4b4ff"
        "--inside-color 1a1a1aff"
        "--line-color b4b4b4ff"
        "--text-color f5f5f5ff"
        "--layout-bg-color 242424ff"
        "--layout-border-color b4b4b4ff"
        "--layout-text-color f5f5f5ff"
        "--show-keyboard-layout"
        "--indicator-caps-lock"
      ]
    else
      "--screenshots --effect-blur 5x3 --show-keyboard-layout --indicator-caps-lock";
  swaymsgExe = lib.getExe' pkgs.sway "swaymsg";
  swaylockFork = lib.escapeShellArg "${swaylockExe} -f ${swaylockArgs}";
  # swayidle(1): timeouts are from the start of each idle period (EXAMPLE). 300s lock, 360s DPMS.
  # -w + swaylock -f so the lock finishes engaging before swayidle drops idle inhibition (man swayidle).
  hmSwayidle = pkgs.writeShellScriptBin "hm-swayidle" ''
    set -eu
    exec ${lib.getExe pkgs.swayidle} -w \
      timeout 300 ${swaylockFork} \
      timeout 360 ${lib.escapeShellArg "${swaymsgExe} -q output * power off"} \
        resume ${lib.escapeShellArg "${swaymsgExe} -q output * power on"} \
      before-sleep ${swaylockFork}
  '';

  systemctlExe = lib.getExe' pkgs.systemd "systemctl";
in
{
  imports = [ ./waybar.nix ];

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

  home.packages =
    with pkgs;
    [
      blueman
      flameshot
      gnome-keyring
      latest.google-chrome
      latest.microsoft-edge
      libnotify
      light
      networkmanagerapplet
      pulseaudio
      rofi
      vscode
      cantarell-fonts
      noto-fonts-color-emoji
    ]
    ++ lib.optionals (!swaylockHost) [ swaylock-effects ]
    ++ [ hmSwayidle ];

  # Chromium does not treat sway as a GNOME-style session, so it will not pick the GNOME
  # password store by itself; `password-store` below forces that. A Secret Service still has
  # to be running (see extraSessionCommands): without gnome-keyring-daemon, there is nothing to talk to.
  # https://github.com/microsoft/vscode/issues/187338
  home.file.".cursor/argv.json".text = builtins.toJSON {
    "enable-crash-reporter" = true;
    "crash-reporter-id" = "48ce64db-5065-4bf3-859d-614652434d83";
    "password-store" = "gnome";
  };

  # Edge can ignore native notifications unless this policy is set (maps to the Linux pref path
  # behind prefs::kAllowSystemNotifications). Chrome already defaults the pref to true.
  xdg.configFile."microsoft-edge/policies/managed/hm-allow-system-notifications.json".text =
    builtins.toJSON {
      AllowSystemNotifications = true;
    };

  programs.alacritty = {
    enable = true;
    settings = {
      keyboard.bindings = [
        { key = "Right"; mods = "Control"; chars = "\x1BF"; }
        { key = "Left"; mods = "Control"; chars = "\x1BB"; }
      ];
      window.padding = {
        x = 10;
        y = 10;
      };
    };
  };

  services.kanshi = {
    enable = true;
  };

  # Desktop notifications (D-Bus-activatable org.freedesktop.Notifications).
  services.mako = {
    enable = true;
    settings = {
      anchor = "top-center";
      font = "Ubuntu 11";
      width = 500;
      margin = 10;
      padding = 12;
      default-timeout = 10000;
      layer = "overlay";
      background-color = "#eff1f5";
      text-color = "#4c4f69";
      border-color = "#df8e1d";
      border-radius = 10;
      progress-color = "over #ccd0da";
      border-size = 1;
      icons = true;
    };
  };

  # Blueman remembers window size in gsettings; a prior tiled session can save something
  # like 1261x1384, which ignores floating_maximum_size once GTK calls resize().
  dconf.settings."org/blueman/general" = {
    window-properties = [ 600 480 0 0 ];
  };

  # Blueman's D-Bus activation files reference blueman-{applet,manager}.service; without
  # these user units, "Devices" in the applet fails with NoSuchUnit.
  systemd.user.services = {
    blueman-applet = {
      Unit = {
        Description = "Bluetooth management applet";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
        Requires = [ "graphical-session.target" ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };
      Service = {
        Type = "dbus";
        BusName = "org.blueman.Applet";
        ExecStart = bluemanAppletExe;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
    blueman-manager = {
      Unit.Description = "Bluetooth Manager";
      Service = {
        Type = "dbus";
        BusName = "org.blueman.Manager";
        ExecStart = bluemanManagerExe;
      };
    };
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
      eval $(${gnomeKeyringDaemonExe} --start --components=secrets)
    '';

    extraConfigEarly = ''
      set $chromeSettings "--enable-features=UseOzonePlatform,NativeNotifications,SystemNotifications --ozone-platform=wayland"
    '';

    # Edge/Chromium sometimes map link-hover / preview UI as an xdg_shell toplevel with empty
    # app_id. Sway would otherwise tile it like a sibling (IPC: tiny geometry, full split rect,
    # focus jump). Float these surfaces instead.
    extraConfig = ''
      for_window [tiling shell="xdg_shell" app_id="^$"] floating enable
    '';

    config = {
      inherit modifier;
      terminal = lib.getExe pkgs.alacritty;
      menu = "${lib.getExe pkgs.rofi} -show run | xargs swaymsg exec --";

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
        { command = nmAppletExe; always = false; }
        {
          command = "${lib.getExe pkgs.bash} -c ${
            lib.escapeShellArg (
              "${dbusUpdateEnvExe} --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway && "
              + "${systemctlExe} --user stop pipewire wireplumber xdg-desktop-portal xdg-desktop-portal-wlr && "
              + "${systemctlExe} --user start wireplumber xdg-desktop-portal"
            )
          }";
          always = false;
        }
        # One instance; `always` false avoids stacking duplicate swayidle on each `reload`.
        { command = "${lib.getExe hmSwayidle}"; always = false; }
        # Sway reload drops runtime output layout; kanshi keeps the same profile pointer and
        # will not re-apply (https://github.com/emersion/kanshi/issues/43). Restart the user unit.
        { command = "${systemctlExe} --user restart kanshi.service"; always = true; }
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
        {
          criteria = { app_id = ".*blueman-manager.*"; };
          command = "floating enable, resize set 600 480, floating_maximum_size 600 x 480";
        }
      ];

      keybindings = lib.mkOptionDefault {
        "${modifier}+Shift+c" = "exec /usr/share/cursor/cursor";
        "${modifier}+Shift+e" = "exec swaynag -t warning -m 'You pressed the exit shortcut. Do you really want to exit sway? This will end your Wayland session.' -B 'Yes, exit sway' 'swaymsg exit'";
        "${modifier}+Shift+f" = "exec ${edgeExe} $chromeSettings --profile-directory=Default --app-id=ompifgpmddkgmclendfeacglnodjjndh --app-url=https://teams.cloud.microsoft/?clientType=pwa";
        "${modifier}+Shift+p" = "exec ${chromeExe} $chromeSettings";
        "${modifier}+Shift+r" = "reload";
        "${modifier}+Shift+t" = "exec ${edgeExe} $chromeSettings --profile-directory=Default --app-id=dlgohinmglaoopaiplliaecdpmnepmga --app-url=https://app.todoist.com/app";
        "${modifier}+Shift+w" = "exec ${edgeExe} $chromeSettings --profile-directory=Default";
        "${modifier}+Shift+x" = "exec ${swaylockExe} ${swaylockArgs}";

        "${modifier}+Control+Left" = "move workspace to output left";
        "${modifier}+Control+Down" = "move workspace to output down";
        "${modifier}+Control+Up" = "move workspace to output up";
        "${modifier}+Control+Right" = "move workspace to output right";

        "${modifier}+f" = "fullscreen";


        Print = "exec ${lib.getExe pkgs.flameshot} gui";
        XF86AudioMute = "exec --no-startup-id ${pactlExe} set-sink-mute 0 toggle";
        XF86AudioLowerVolume = "exec --no-startup-id ${pactlExe} set-sink-volume 0 -5%";
        XF86AudioRaiseVolume = "exec --no-startup-id ${pactlExe} set-sink-volume 0 +5%";
        XF86MonBrightnessDown = "exec --no-startup-id ${lightExe} -U 5";
        XF86MonBrightnessUp = "exec --no-startup-id ${lightExe} -A 5";
      };

      workspaceOutputAssign = [
        { output = "DP-4"; workspace = "1"; }
        { output = "DP-4"; workspace = "2"; }
        { output = "DP-4"; workspace = "3"; }
        { output = "DP-6"; workspace = "4"; }
        { output = "DP-6"; workspace = "5"; }
        { output = "DP-6"; workspace = "6"; }
        { output = "DP-6"; workspace = "7"; }
        { output = "DP-6"; workspace = "8"; }
        { output = "DP-6"; workspace = "9"; }
        { output = "DP-6"; workspace = "0"; }
      ];
    };
  };
}
