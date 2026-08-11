{ config
, lib
, pkgs
, ...
}:
let
  # GDM on Ubuntu only lists system-wide Wayland sessions (e.g. /usr/share/wayland-sessions).
  # /usr/local is a good place for an admin-managed session that runs the Home Manager profile's
  # sway (see /usr/local/bin/sway-nix). After `apt remove sway`, pick "Sway (Nix)" at the greeter.
  # On `home-manager switch -b backup --flake .#''${USER}` this activation prompts for sudo once
  # when the launcher or desktop file is missing or out of date.

  gdmSwayNixEnabled =
    pkgs.stdenv.isLinux && config.targets.genericLinux.enable && config.wayland.windowManager.sway.enable;

  swayNixLauncher = pkgs.writeText "sway-nix" ''
    #!/usr/bin/env bash
    set -euo pipefail
    exec "''${HOME}/.nix-profile/bin/sway" "''$@"
  '';

  swayNixDesktop = pkgs.writeText "sway-nix.desktop" ''
    [Desktop Entry]
    Name=Sway (Nix)
    Comment=i3-compatible Wayland compositor (Home Manager / Nix profile)
    Exec=/usr/local/bin/sway-nix
    Type=Application
    DesktopNames=sway;wlroots
  '';

  installGdmSwayNixFiles = pkgs.writeShellScript "hm-install-gdm-sway-nix" ''
    set -euo pipefail
    PATH="${lib.makeBinPath [ pkgs.coreutils ]}"
    install -d /usr/local/share/wayland-sessions
    install -m755 ${swayNixLauncher} /usr/local/bin/sway-nix
    install -m644 ${swayNixDesktop} /usr/local/share/wayland-sessions/sway-nix.desktop
  '';

  # Sway binds XF86MonBrightness* to `light` (modules/sway.nix). On Ubuntu, sysfs backlight
  # is root:root 0644 so `light` fails silently until udev chowns to video (use %k, not %S%p).
  # Also adds the user to `video` on first switch; re-login once if needed. Test: `light -A 5`.
  genericLinuxBacklightEnabled = pkgs.stdenv.isLinux && config.targets.genericLinux.enable;

  backlightUdevRule = pkgs.writeText "90-hm-backlight.rules" ''
    SUBSYSTEM=="backlight", TAG+="uaccess"
    SUBSYSTEM=="backlight", ACTION=="add", RUN+="/usr/bin/chgrp video /sys/class/backlight/%k/brightness", RUN+="/usr/bin/chmod g+w /sys/class/backlight/%k/brightness"
  '';

  installBacklightUdevFiles = pkgs.writeShellScript "hm-install-backlight-udev" ''
    set -euo pipefail
    install -d /etc/udev/rules.d
    install -m644 ${backlightUdevRule} /etc/udev/rules.d/90-hm-backlight.rules
    /usr/bin/udevadm control --reload-rules
    /usr/bin/udevadm trigger --subsystem-match=backlight --action=add
  '';

  kanshiOutput =
    screen:
    { status, ... } @ args:
    {
      criteria = screen.criteria;
      inherit status;
    }
    // lib.optionalAttrs (status == "enable") { mode = screen.mode; }
    // lib.removeAttrs args [ "status" ];

  laptopScreen = {
    criteria = "BOE 0x0B99 Unknown";
    mode = "1920x1200@60.002";
  };

  espressoScreen = {
    criteria = "ESP eD15T(2022)*";
    mode = "1920x1080@60.000";
  };
in
{
  imports = [
    ./home.nix
    ./modules/sway.nix
    ./modules/cursor-mintel-skills.nix
  ];

  # `_module` configures the Nix module evaluator (not normal HM options).
  # `args` injects extra function parameters into every module in this config,
  # so `home.nix` can take `{ username, ... }` without `mkForce` on `home.*`.
  _module.args.username = "bbrockway";

  # My work laptop runs Ubuntu 24.04
  targets.genericLinux.enable = true;
  # Sway uses /usr/bin/swaylock (see modules/sway.nix).  Install: sudo apt install -y swaylock

  home.activation = lib.mkMerge [
    (lib.mkIf gdmSwayNixEnabled {
      installGdmSwayNixSession = lib.hm.dag.entryAfter [ "installPackages" ] ''
        set -eu
        launcher=${lib.escapeShellArg swayNixLauncher}
        desktop=${lib.escapeShellArg swayNixDesktop}
        installer=${lib.escapeShellArg installGdmSwayNixFiles}
        cmp=${lib.escapeShellArg "${pkgs.diffutils}/bin/cmp"}

        update=
        if [ ! -f /usr/local/bin/sway-nix ] || ! "$cmp" -s "$launcher" /usr/local/bin/sway-nix; then
          update=1
        fi
        if [ ! -f /usr/local/share/wayland-sessions/sway-nix.desktop ] || ! "$cmp" -s "$desktop" /usr/local/share/wayland-sessions/sway-nix.desktop; then
          update=1
        fi

        if [ -n "$update" ]; then
          echo "home-manager: GDM Sway (Nix) session files missing or outdated; installing under /usr/local (sudo)." >&2
          $DRY_RUN_CMD /usr/bin/sudo "$installer"
        fi
      '';
    })
    (lib.mkIf genericLinuxBacklightEnabled {
      installBacklightUdev = lib.hm.dag.entryAfter [ "installPackages" ] ''
        set -eu
        rule=${lib.escapeShellArg backlightUdevRule}
        installer=${lib.escapeShellArg installBacklightUdevFiles}
        cmp=${lib.escapeShellArg "${pkgs.diffutils}/bin/cmp"}

        update=
        if [ ! -f /etc/udev/rules.d/90-hm-backlight.rules ] || ! "$cmp" -s "$rule" /etc/udev/rules.d/90-hm-backlight.rules; then
          update=1
        fi

        if [ -n "$update" ]; then
          echo "home-manager: backlight udev rule missing or outdated; installing (sudo)." >&2
          $DRY_RUN_CMD /usr/bin/sudo "$installer"
        else
          # Re-trigger in case sysfs perms were never applied after a rule change.
          $DRY_RUN_CMD /usr/bin/sudo /usr/bin/udevadm control --reload-rules
          $DRY_RUN_CMD /usr/bin/sudo /usr/bin/udevadm trigger --subsystem-match=backlight --action=add
        fi

        if ! id -nG "''${USER}" | tr ' ' '\n' | grep -qx video; then
          echo "home-manager: adding ''${USER} to video group for backlight control (sudo)." >&2
          $DRY_RUN_CMD /usr/bin/sudo /usr/sbin/usermod -aG video "''${USER}"
          echo "home-manager: log out and back in if brightness keys still fail after switch." >&2
        fi
      '';
    })
  ];

  # Dock monitor output names (host-specific; kanshi profiles below use the same hardware).
  wayland.windowManager.sway.config.workspaceOutputAssign = [
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

  # Settings for kanshi service (autorandr replacement) to auto-configure display settings based on what is connected.
  services.kanshi.settings = [
    {
      profile.name = "laptop_only";
      profile.outputs = [
        (kanshiOutput laptopScreen { status = "enable"; position = "0,0"; })
      ];
    }
    {
      profile.name = "home_docked";
      profile.outputs = [
        (kanshiOutput laptopScreen { status = "disable"; })
        (kanshiOutput espressoScreen { status = "enable"; position = "310,1440"; })
        {
          criteria = "Ancor Communications Inc ROG PG279Q*";
          status = "enable";
          mode = "2560x1440@59.951";
          position = "0,0";
        }
      ];
    }
    {
      profile.name = "work_docked";
      profile.outputs = [
        (kanshiOutput laptopScreen { status = "enable"; position = "310,1440"; })
        {
          criteria = "Dell Inc. DELL U2722D*";
          status = "enable";
          mode = "2560x1440@59.951";
          position = "0,0";
        }
      ];
    }
  ];
}
