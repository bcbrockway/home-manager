{
  config,
  lib,
  pkgs,
  ...
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

  home.activation = lib.mkIf gdmSwayNixEnabled {
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
  };

  # Get PrtSc key to work properly with Flameshot in GNOME
  dconf.settings = {
    "org/gnome/shell/keybindings" = {
      show-screenshot-ui = [];
    };
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
      ];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name = "Flameshot";
      command = "script -q -c 'flameshot gui' /dev/null";
      binding = "Print";
    };
  };

  # Settings for kanshi service (autorandr replacement) to auto-configure display settings based on what is connected.
  services.kanshi.settings = [
    {
      profile.name = "laptop_only";
      profile.outputs = [
        {
          criteria = "BOE 0x0B99 Unknown";
          status = "enable";
          mode = "1920x1200@60.002";
          position = "0,0";
        }
      ];
    }
    {
      profile.name = "home_docked";
      profile.outputs = [
        {
          criteria = "Ancor Communications Inc ROG PG279Q*";
          status = "enable";
          mode = "2560x1440@59.951";
          position = "0,0";
        }
        {
          criteria = "ESP eD15T(2022)*";
          status = "enable";
          mode = "1920x1080@60.000";
          position = "310,1440";
        }
        {
          criteria = "BOE 0x0B99 Unknown";
          status = "disable";
        }
      ];
    }
  ];
}
