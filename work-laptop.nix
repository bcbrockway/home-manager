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
  # This file is only imported by the work-laptop profile (vagrant.nix imports home.nix
  # directly), so gating /etc-touching activations on genericLinux is laptop-only.
  genericLinuxEnabled = pkgs.stdenv.isLinux && config.targets.genericLinux.enable;

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

  # The lid stays permanently closed (docked WD19TB). systemd-logind's default
  # HandleLidSwitch=suspend fires in the pre-login boot window — no session
  # exists yet to inhibit it — so some boots suspend right after the disk
  # password (journal: "PM: suspend entry (s2idle)" ~2s after boot); screens
  # stay black until the lid is opened to wake it. Ignore the lid system-wide;
  # running desktop sessions still handle lid events via their own settings.
  # HM release-25.11 has no services.logind module, hence the sudo drop-in.
  logindLidDropIn = pkgs.writeText "00-hm-docked-lid.conf" ''
    [Login]
    HandleLidSwitch=ignore
    HandleLidSwitchExternalPower=ignore
    HandleLidSwitchDocked=ignore
  '';

  installLogindLidFiles = pkgs.writeShellScript "hm-install-logind-lid" ''
    set -euo pipefail
    install -d /etc/systemd/logind.conf.d
    install -m644 ${logindLidDropIn} /etc/systemd/logind.conf.d/00-hm-docked-lid.conf
    # logind only re-reads drop-ins on restart; safe on systemd 255+.
    /usr/bin/systemctl restart systemd-logind
  '';

  # Verbose boot/shutdown console (no `quiet splash`). grub-mkconfig sources
  # /etc/default/grub.d/*.cfg after /etc/default/grub, so this assignment wins.
  # Kept because console output is preferred, and it made an intermittent
  # shutdown freeze visible at power-off (kernel oops in intel_ipu6_isys,
  # 2026-10). Revert: delete the drop-in and run update-grub.
  grubConsoleDropIn = pkgs.writeText "00-hm-console.cfg" ''
    GRUB_CMDLINE_LINUX_DEFAULT="init=/lib/systemd/systemd"
  '';

  installGrubConsoleFiles = pkgs.writeShellScript "hm-install-grub-console" ''
    set -euo pipefail
    install -d /etc/default/grub.d
    install -m644 ${grubConsoleDropIn} /etc/default/grub.d/00-hm-console.cfg
    /usr/sbin/update-grub
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
  # nm-applet uses /usr/bin/nm-applet for VPN editor plugins.  Install: sudo apt install -y network-manager-openvpn-gnome

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
    (lib.mkIf genericLinuxEnabled {
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
    (lib.mkIf genericLinuxEnabled {
      installLogindLid = lib.hm.dag.entryAfter [ "installPackages" ] ''
        set -eu
        dropin=${lib.escapeShellArg logindLidDropIn}
        installer=${lib.escapeShellArg installLogindLidFiles}
        cmp=${lib.escapeShellArg "${pkgs.diffutils}/bin/cmp"}

        update=
        if [ ! -f /etc/systemd/logind.conf.d/00-hm-docked-lid.conf ] || ! "$cmp" -s "$dropin" /etc/systemd/logind.conf.d/00-hm-docked-lid.conf; then
          update=1
        fi

        if [ -n "$update" ]; then
          echo "home-manager: logind lid drop-in missing or outdated; installing (sudo)." >&2
          $DRY_RUN_CMD /usr/bin/sudo "$installer"
        fi
      '';
    })
    (lib.mkIf genericLinuxEnabled {
      installGrubConsole = lib.hm.dag.entryAfter [ "installPackages" ] ''
        set -eu
        dropin=${lib.escapeShellArg grubConsoleDropIn}
        installer=${lib.escapeShellArg installGrubConsoleFiles}
        cmp=${lib.escapeShellArg "${pkgs.diffutils}/bin/cmp"}

        update=
        if [ ! -f /etc/default/grub.d/00-hm-console.cfg ] || ! "$cmp" -s "$dropin" /etc/default/grub.d/00-hm-console.cfg; then
          update=1
        fi

        if [ -n "$update" ]; then
          echo "home-manager: GRUB console drop-in missing or outdated; installing and running update-grub (sudo)." >&2
          $DRY_RUN_CMD /usr/bin/sudo "$installer"
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
