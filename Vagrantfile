# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "alvistack/ubuntu-24.04"

  config.ssh.insert_key = false
  
  config.vm.provision "shell", privileged: true, inline: <<-SHELL
    # INSTALL OS PACKAGES
    apt-get update
    apt-get install -y --no-install-recommends git  
    
    # ADD MY USER 
    if ! id -u bbrockway >/dev/null 2>&1; then
      useradd -m -s /bin/bash -G sudo bbrockway
      install -d -m 700 -o bbrockway -g bbrockway /home/bbrockway/.ssh
      curl -fsSL https://raw.githubusercontent.com/hashicorp/vagrant/master/keys/vagrant.pub \
      -o /home/bbrockway/.ssh/authorized_keys
      chown bbrockway:bbrockway /home/bbrockway/.ssh/authorized_keys
      chmod 600 /home/bbrockway/.ssh/authorized_keys
    
      echo "bbrockway ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/99-bbrockway
      chmod 440 /etc/sudoers.d/99-bbrockway
    fi
      
    # INSTALL NIX
    if [[ ! -d /nix ]]; then
      sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon
    fi
    if ! grep -P "experimental-features" /etc/nix/nix.conf; then
      echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf
    fi
    SHELL
    
    config.vm.provision "shell", privileged: false, inline: <<-SHELL
    if ! command -v home-manager; then
      nix profile add nixpkgs#home-manager
    fi
  SHELL
  
  # Only uncomment this after provisioning
  # config.ssh.username = "bbrockway"
end
