{ ... }:
{
  imports = [
    ./home.nix
    ./modules/sway.nix
  ];

  # `_module` configures the Nix module evaluator (not normal HM options).
  # `args` injects extra function parameters into every module in this config,
  # so `home.nix` can take `{ username, ... }` without `mkForce` on `home.*`.
  _module.args.username = "bbrockway";

  # My work laptop runs Ubuntu 24.04
  targets.genericLinux.enable = true;

  # Get Flameshot to work in GNOME
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
          criteria = "Ancor Communications Inc ROG PG279Q #ASMleldyziLd";
          status = "enable";
          mode = "2560x1440@59.951";
          position = "0,0";
        }
        {
          criteria = "ESP eD15T(2022) ";
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
