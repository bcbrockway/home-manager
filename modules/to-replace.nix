{ config, lib, pkgs, ... }:

{
  services.ssh-agent = {
    enable = true;
    enableZshIntegration = true;
  };
}
