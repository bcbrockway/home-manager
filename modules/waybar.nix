{ pkgs, ... }:
{
  programs.waybar = {
    enable = true;
    systemd.enable = false;
    style = ''
      * {
        border: none;
        border-radius: 0;
        font-family: Ubuntu, "Font Awesome 7 Free", "Font Awesome 7 Brands", sans-serif;
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

      #mode, #clock, #battery, #custom-ping-latency {
        padding: 0 10px;
      }

      #mode {
        background: #64727D;
      }

      #clock, #custom-ping-latency {
        background-color: #242424;
      }

      #battery {
        background-color: #242424;
        color: white;
      }

      #battery.charging {
        color: white;
        background-color: #26A65B;
      }

      #tray {
        background-color: #242424;
        padding-right: 10px;
      }

      #battery.critical:not(.charging) {
        background: #f53c3c;
        color: white;
      }
    '';
    settings.mainBar = {
      layer = "top";
      position = "top";
      height = 32;
      spacing = 10;
      modules-left = [
        "sway/workspaces"
        "sway/mode"
      ];
      modules-center = [ "clock" ];
      modules-right = [
        "battery"
        "custom/ping-latency"
        "tray"
      ];
      "sway/workspaces" = {
        disable-scroll = true;
      };
      "clock".format = "{:%d/%m/%Y %H:%M}";
      "custom/ping-latency" = {
        # Ubuntu's /usr/bin/ping has cap_net_raw=ep; the nixpkgs iputils ping may not
        exec = pkgs.writeShellScript "waybar-ping-latency" ''
          ms=$(/usr/bin/ping -c 1 -W 2 8.8.8.8 2>/dev/null | ${pkgs.gnugrep}/bin/grep -oP 'time=\K[0-9.]+' | head -1)
          if [ -n "$ms" ]; then
            printf '\uf1a0 : %.0f ms\n' "$ms"
          else
            echo "— ms"
          fi
        '';
        interval = 5;
        tooltip = false;
      };
      battery = {
        bat = "BAT0";
        interval = 30;
        states = {
          critical = 15;
        };
        format = "{capacity}% {icon}";
        format-charging = "{capacity}% ";
        format-plugged = "{capacity}% ";
        format-icons = [
          ""
          ""
          ""
          ""
          ""
        ];
      };
      "tray" = {
        "icon-size" = 16;
        spacing = 10;
      };
    };
  };
}
