# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repository manages a personal development environment using Nix Home Manager with flakes. It configures packages,
shell environment (zsh), git settings, and various development tools primarily for AWS/Kubernetes infrastructure work
with Terragrunt.

## Key Commands

### Apply Configuration
```bash
# Apply home-manager configuration using flake
home-manager switch --flake .#bbrockway

# Or use task shortcut
task update
```

### Cleanup
```bash
# Remove old generations and free up space
nix-collect-garbage -d

# Or use task shortcut
task clean
```

### Vagrant Environment
```bash
# Provision test VM with Nix and home-manager installed
vagrant up

# SSH into VM (after initial provisioning, uncomment config.ssh.username in Vagrantfile)
vagrant ssh

# Apply minimal Sway-only home-manager profile in the VM
home-manager switch --flake .#vagrant
```

## Architecture

I'm running Ubuntu 24.04. Nix is installed in a multi-user configuration with nix-command and flakes enabled in
/etc/nix/nix.conf.

### Configuration Structure

- **flake.nix**: Nix flake entrypoint that:
  - Pins nixpkgs to `release-25.11` and exposes `nixpkgs-unstable` as `latest` for selected packages
  - Follows home-manager `release-25.11`
  - Allows unfree packages (e.g. `claude-code`, browser packages in sway module)
  - Defines `bbrockway` (work laptop) and `vagrant` (minimal VM) home configurations

- **work-laptop.nix**: Host entry for the work laptop; imports `home.nix`, sway, and cursor skills modules. Sets
  `targets.genericLinux`, GDM Sway session install, kanshi display profiles, and GNOME Flameshot keybinding.

- **home.nix**: Shared home-manager configuration defining:
  - User: `bbrockway` (overridable via `_module.args.username`)
  - Package installations (AWS, Kubernetes, development utilities)
  - Git configuration (user info, LFS, submodules)
  - Zsh with Oh My Zsh, mise, and password-store

- **modules/sway.nix**: Sway, waybar, GTK/fonts, kanshi service, mako, blueman, browser/Cursor config

- **modules/cursor-mintel-skills.nix**: Activation hook to sync Mintel claude-code-plugins into `~/.cursor/skills`

- **vagrant.nix**: Imports `home.nix` and sway for a realistic VM test profile; overrides username/homeDirectory for the `vagrant` user

- **Vagrantfile**: Provisions Ubuntu 24.04 VM with:
  - Nix multi-user installation with flakes enabled
  - Custom user `bbrockway` with sudo access
  - Ready for home-manager setup

### Custom Shell Functions (in home.nix)

Key zsh functions configured in `programs.zsh.siteFunctions`:

- **aws_env** (alias `ae`): Spawn new shell with AWS_PROFILE set
- **adecode**: Decode AWS authorization messages
- **tgau**: Clean terragrunt cache and reinitialize
- **tgclean**: Recursively remove terraform/terragrunt cache directories
- **selfheal** (alias `setf`): Toggle ArgoCD application auto-sync/self-heal settings

### Environment Configuration

- Shell: zsh with Oh My Zsh (robbyrussell theme)
- Plugins: aws, direnv, git, kube-ps1, kubectl, timer
- mise version manager integrated
- Vagrant default provider: libvirt
- AWS SSO login on shell start when AWS_PROFILE is set

### Package Categories

The configuration installs packages across several domains:

- **AWS**: aws-nuke, awscli2
- **Kubernetes**: k9s, kubectl, kubectx, kubernetes-helm, stern, telepresence2, velero
- **Development**: go, go-task, pre-commit, direnv, uv, terraform, cue, d2, jsonnet, nodejs
- **Utilities**: github-cli, glab, grim, slurp, swappy, wl-clipboard, jq, yq-go
- **Applications**: claude-code, joplin-desktop, obsidian, devbox, vsce

Sway-related packages (flameshot, browsers, rofi, etc.) are in `modules/sway.nix`. On Ubuntu, swaylock comes from apt
(`sudo apt install -y swaylock`); Nix `swaylock-effects` is used only on non-genericLinux hosts.

### Terragrunt Workflow

Extensive shell aliases configured for terragrunt operations with common patterns:
- Single module operations: tgi, tga, tgp, tgd (init, apply, plan, destroy)
- Multi-module operations: tgia, tgaa, tgpa, tgda (run-all variants)
- Source updates: tgau, tgpu, tgpau, tgdau (with --terragrunt-source-update)
- All commands use --terragrunt-no-auto-init except init
- Parallelism set to 4 for run-all operations
- Plans saved to `planfile` (gitignore also lists `.planfile`)
