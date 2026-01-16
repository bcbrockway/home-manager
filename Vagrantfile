# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.box = "alvistack/ubuntu-24.04"

  config.vm.provider :libvirt do |libvirt|
    libvirt.graphics_type = "spice"
    libvirt.video_type = "virtio"
    libvirt.video_vram = 524288
    libvirt.memory = 8192  # Increase for desktop usage
    libvirt.cpus = 2
    libvirt.keymap = "en-gb"
  end

  config.ssh.insert_key = false
  
  # Sync current directory to /vagrant in the VM
  config.vm.synced_folder ".", "/vagrant", type: "rsync",
  rsync__exclude: [".git/", ".vagrant/"],
  rsync__auto: true
  
  config.vm.provision "shell", privileged: true, inline: <<-SHELL
    # INSTALL OS PACKAGES
    apt-get update
    apt-get install -y --no-install-recommends git
    
    # INSTALL NIX
    if [[ ! -d /nix ]]; then
      sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon
      fi
      if ! grep -P "experimental-features" /etc/nix/nix.conf; then
        echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf
        fi      
  SHELL
  
  # Set this after installing zsh with home-manager
  config.ssh.extra_args = ["-t", "cd /vagrant; exec zsh --login"]
end
