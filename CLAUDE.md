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
```

## Architecture

I'm running Ubuntu 24.04. Nix is installed in a multi-user configuration with nix-command and flakes enabled in
/etc/nix/nix.conf.

### Configuration Structure

- **flake.nix**: Nix flake entrypoint that:
  - Pins nixpkgs to unstable channel
  - Follows home-manager master branch
  - Allows unfree package `claude-code`
  - Defines `bbrockway` home configuration for x86_64-linux

- **home.nix**: Main home-manager configuration defining:
  - User: `bbrockway`
  - Package installations (AWS tools, Kubernetes tools, development utilities)
  - Git configuration (user info, LFS, submodules)
  - Zsh configuration with Oh My Zsh
  - XDG desktop entries (e.g., Joplin)

- **Vagrantfile**: Provisions Ubuntu 24.04 VM with:
  - Nix multi-user installation with flakes enabled
  - Custom user `bbrockway` with sudo access
  - Ready for home-manager setup

### Custom Shell Functions (in home.nix)

Key zsh functions configured in `programs.zsh.siteFunctions`:

- **ae**: Spawn new shell with AWS_PROFILE set
- **adecode**: Decode AWS authorization messages
- **tgau**: Clean terragrunt cache and reinitialize
- **tgclean**: Recursively remove terraform/terragrunt cache directories
- **selfheal**: Toggle ArgoCD application auto-sync/self-heal settings
- **setf**: Alias for selfheal (appears duplicated in config)

### Environment Configuration

- Shell: zsh with Oh My Zsh (robbyrussell theme)
- Plugins: aws, direnv, git, kube-ps1, kubectl, timer
- ASDF version manager integrated
- Vagrant default provider: libvirt
- AWS SSO login on shell start when AWS_PROFILE is set

### Package Categories

The configuration installs packages across several domains:

- **AWS**: aws-nuke, awscli2
- **Kubernetes**: k9s, kubectl, kubectx, kubernetes-helm
- **Development**: go, go-task, pre-commit, direnv, uv
- **Utilities**: github-cli, d2, grim, slurp, swappy, swaylock-effects
- **Applications**: claude-code, joplin-desktop, vscode, warp-terminal

### Terragrunt Workflow

Extensive shell aliases configured for terragrunt operations with common patterns:
- Single module operations: tgi, tga, tgp, tgd (init, apply, plan, destroy)
- Multi-module operations: tgia, tgaa, tgpa, tgda (run-all variants)
- Source updates: tgau, tgpu, tgpau, tgdau (with --terragrunt-source-update)
- All commands use --terragrunt-no-auto-init except init
- Parallelism set to 4 for run-all operations
- Plans saved to `.planfile` (in gitignore)
