# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.box = "alvistack/ubuntu-24.04"

  config.vm.provider :libvirt do |libvirt|
    libvirt.graphics_type = "spice"
    # QXL pairs cleanly with SPICE. Virtio GPU + SPICE often shows stale frames
    # (e.g. Sway/wlroots only repainting when the pointer moves) until the VM is recreated.
    libvirt.video_type = "qxl"
    libvirt.video_vram = 65536
    libvirt.memory = 8192  # Increase for desktop usage
    libvirt.cpus = 2
    libvirt.keymap = "en-gb"
  end

  config.ssh.insert_key = false
  
  # Sync current directory to /vagrant in the VM.
  # Remote rsync must run as root so it can write into /vagrant when the box
  # ships that directory as root-owned; owner/group tell Vagrant to chown the
  # tree to vagrant after sync (needed for Nix reading the flake).
  config.vm.synced_folder ".", "/vagrant", type: "rsync",
  owner: "vagrant",
  group: "vagrant",
  rsync__exclude: [".git/", ".vagrant/"],
  rsync__auto: true

  config.vm.provision "shell", privileged: true, inline: <<-SHELL
    chown -R vagrant:vagrant /vagrant

    # INSTALL OS PACKAGES
    # apt-get update
    apt-get install -y --no-install-recommends git swaylock
    
    # INSTALL NIX
    if [[ ! -d /nix ]]; then
      sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install) --daemon
      fi
      if ! grep -P "experimental-features" /etc/nix/nix.conf; then
        echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf
        fi      
  SHELL

  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    set -euo pipefail
    if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
      . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    elif [[ -f "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
      . "$HOME/.nix-profile/etc/profile.d/nix.sh"
    fi
    cd /vagrant
    # Uses packages.x86_64-linux.home-manager from this flake (same rev as inputs.home-manager / flake.lock)
    nix run .#home-manager -- switch --flake .#vagrant
  SHELL

  # Do not use config.ssh.extra_args for "cd ...; exec zsh" — Vagrant passes
  # extra_args to every SSH session, including rsync synced folders, which
  # breaks rsync (ssh exits before the remote rsync binary runs).
  #
  # After zsh/home-manager is set up on the guest, use either:
  #   vagrant ssh -- -t "cd /vagrant && exec zsh -l"
  # or change the vagrant user's login shell (chsh) in provisioning.
end
