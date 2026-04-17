{ ... }:
{
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
}
