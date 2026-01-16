{ lib, ... }:
{
  imports = [
    ./home.nix
    ./modules/sway.nix
    ./modules/to-replace.nix
  ];

  # Override username for Vagrant environment
  home.username = lib.mkForce "vagrant";
  home.homeDirectory = lib.mkForce "/home/vagrant";

  # Override oh-my-zsh custom path for Vagrant user
  programs.zsh.oh-my-zsh.custom = lib.mkForce "/home/vagrant/.oh-my-zsh/custom";
}
