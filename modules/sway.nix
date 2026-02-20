{
  config,
  lib,
  pkgs,
  ...
}:

{
  wayland.windowManager.sway = {
    enable = true;
    # Add your sway configuration here
  };
}
