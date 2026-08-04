{ lib, ... }:
{
  imports = [
    ./home.nix
    ./modules/sway.nix
  ];

  _module.args.username = "vagrant";
  targets.genericLinux.enable = true;

  home.username = lib.mkForce "vagrant";
  home.homeDirectory = lib.mkForce "/home/vagrant";
  programs.zsh.oh-my-zsh.custom = lib.mkForce "/home/vagrant/.oh-my-zsh/custom";
}
