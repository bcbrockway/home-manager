{ lib, pkgs, pkgs-unstable, ... }: let
  username = "bbrockway";
in {
  
  targets.genericLinux.enable = true;
  
  home = {
    inherit username;
    homeDirectory = "/home/${username}";
    keyboard.layout = "uk";
  };

  home.packages = with pkgs; [
    aws-nuke
    awscli2
    claude-code
    d2
    direnv
    github-cli
    go
    go-task
    grim
    pkgs-unstable.joplin-desktop
    k9s
    kubectl
    kubectx
    kubernetes-helm
    pre-commit
    slurp
    stern
    swappy
    swaylock-effects
    terraform
    uv
    vscode
    warp-terminal
  ];

  xdg = {
    enable = true;
    autostart.enable = true;
    mime.enable = true;
    desktopEntries = {
      code = {
        name = "Visual Studio Code";
        categories = ["Utility" "TextEditor" "Development" "IDE"];
        comment = "Code Editing. Redefined.";
        exec = "code --no-sandbox %F";
        genericName = "Text Editor";
        icon = "vscode";
        startupNotify = true;
        type = "Application";
        actions."new-empty-window" = {
          exec = "code --no-sandbox --new-window %F";
          icon = "vscode";
          name = "New Empty Window";
        };
	settings = {
          Keywords = "vscode";
          StartupWMClass = "Code";
          Version = "1.4";
        };
      };
    };
  };

  programs.git = {
    enable = true;
    userName = "Bobby Brockway";
    userEmail = "bbrockway@mintel.com";
    ignores = [
      ".direnv/"
      ".idea/"
      ".venv/"
      ".planfile"
    ];
    extraConfig = {
      diff.submodule = "log";
      filter.lfs = {
        smudge = "git-lfs smudge -- %f";
        process = "git-lfs filter-process";
        required = true;
        clean = "git-lfs clean -- %f";
      };
      init.defaultBranch = "main";
      pull.rebase = false;
      status.submoduleSummary = true;
    };
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initContent = ''
      # FUNCTIONS
      aws_env() {
        AWS_PROFILE="$1" zsh
      }

      adecode() {
        aws sts decode-authorization-message --encoded-message="$1" --query="DecodedMessage" --output="text" | jq .
      }

      tgau() {
        rm -rf .terragrunt-cache && terragrunt init -upgrade && terragrunt apply --terragrunt-no-auto-init
      }

      tgclean() {
        if [[ -z $1 ]]; then
          echo "ERROR: Must provide path"
          exit 1
        else
          find $1 -type d -regex ".*\.terra\(form\|grunt-cache\)" -exec rm -rf {} \;
        fi
      }

      selfheal() {
        local STATUS; STATUS=$1; shift
        local APP_NAMES; APP_NAMES=( "$@" )
        local onJSON; onJSON='{"spec": {"syncPolicy": {"automated":{"allowEmpty": false, "prune": true, "selfHeal": true}}}}'
        local offJSON; offJSON='{"spec": {"syncPolicy": null}}'
 
        if [[ $STATUS == off ]]; then
            kubectl patch -n argocd app argocd-bootstrap --patch "''${offJSON}" --type merge
            for APP_NAME in "''${APP_NAMES[@]}"; do
              kubectl patch -n argocd app "$APP_NAME" --patch "''${offJSON}" --type merge
            done
        elif [[ $STATUS == on ]]; then
          if [[ ''${#APP_NAMES[@]} -eq 0 ]]; then
            kubectl patch -n argocd app argocd-bootstrap --patch "''${onJSON}" --type merge
          else
            for APP_NAME in "''${APP_NAMES[@]}"; do
              kubectl patch -n argocd app "$APP_NAME" --patch "''${onJSON}" --type merge
            done
          fi
        else
          echo "first argument should be \"off\" or \"on\""
          exit
        fi
      }
      
      setf() {
        local STATUS; STATUS=$1; shift
        local APP_NAMES; APP_NAMES=( "$@" )
        local onJSON; onJSON='{"spec": {"syncPolicy": {"automated":{"allowEmpty": false, "prune": true, "selfHeal": true}}}}'
        local offJSON; offJSON='{"spec": {"syncPolicy": null}}'
 
        if [[ $STATUS == off ]]; then
            kubectl patch -n argocd app argocd-bootstrap --patch "''${offJSON}" --type merge
            for APP_NAME in "''${APP_NAMES[@]}"; do
              kubectl patch -n argocd app "$APP_NAME" --patch "''${offJSON}" --type merge
            done
        elif [[ $STATUS == on ]]; then
          if [[ ''${#APP_NAMES[@]} -eq 0 ]]; then
            kubectl patch -n argocd app argocd-bootstrap --patch "''${onJSON}" --type merge
          else
            for APP_NAME in "''${APP_NAMES[@]}"; do
              kubectl patch -n argocd app "$APP_NAME" --patch "''${onJSON}" --type merge
            done
          fi
        else
          echo "first argument should be \"off\" or \"on\""
          exit
        fi
      }

      # PROMPT MANIPULATION
      PROMPT='%{$fg_bold[green]%}''${AWS_VAULT}%{''$reset_color%}''${ret_status} %{''$fg[cyan]%}%~%{''$reset_color%} ''$(git_prompt_info) ''$(kube_ps1)
      ''$ '
      
      # AWS PROFILE LOGIN
      if [ -n "''$AWS_PROFILE" ]; then
        export PROMPT="''$(tput setab 1)<<''${AWS_PROFILE}>>''$(tput sgr0) ''${PROMPT}"
        aws sso login --profile "''$AWS_PROFILE"
        #eval ''$(aws configure export-credentials --profile dev --format env)
        export AWS_ROLE_ARN=''$(aws sts get-caller-identity | jq -r .Arn)
      fi
      
      # ASDF
      . "$HOME/.asdf/asdf.sh"
      # append completions to fpath
      fpath=(''${ASDF_DIR}/completions $fpath)
      # initialise completions with ZSH's compinit
      autoload -Uz compinit && compinit

      # VAGRANT
      export VAGRANT_DEFAULT_PROVIDER=libvirt

      # GO
      export GOBIN="''${HOME}/go/bin"
      export PATH="$PATH:$GOBIN"

      # SCRIPTS
      export PATH="$PATH:''${HOME}/scripts"
    '';
     shellAliases = {
      # apt
      apti = "sudo apt install ";
      aptl = "sudo apt list ";
      aptlu = "sudo apt list --upgradable ";
      aptr = "sudo apt remove ";
      aptud = "sudo apt update ";
      aptug = "sudo apt upgrade ";

      # aws
      ae = "aws_env ";
      
      # general
      dirs = "dirs -v";
      ll = "ls -l";
      setclip = "xclip -selection c";
      getclip = "xclip -selection c -o";

      # kubernetes
      kc = "kubectx ";
      
      # terragrunt
      tga = "terragrunt apply --terragrunt-no-auto-init";
      tgap = "terragrunt apply planfile --terragrunt-no-auto-init";
      tgaa = "terragrunt run-all apply --terragrunt-parallelism 4 --terragrunt-no-auto-init";
      tgaap = "terragrunt run-all apply planfile --terragrunt-parallelism 4 --terragrunt-no-auto-init";
      tgaau = "terragrunt run-all apply --terragrunt-source-update --terragrunt-parallelism 4 --terragrunt-no-auto-init";
      tgd = "terragrunt destroy --terragrunt-no-auto-init";
      tgda = "terragrunt run-all destroy --terragrunt-parallelism 4 --terragrunt-no-auto-init";
      tgdau = "terragrunt run-all destroy --terragrunt-source-update --terragrunt-parallelism 4 --terragrunt-no-auto-init";
      tgdu = "terragrunt destroy --terragrunt-source-update --terragrunt-no-auto-init";
      tgi = "terragrunt init -upgrade";
      tgia = "terragrunt run-all init -upgrade --terragrunt-parallelism 4";
      tgo = "terragrunt output --terragrunt-no-auto-init";
      tgp = "terragrunt plan -out=planfile --terragrunt-no-auto-init";
      tgpa = "terragrunt run-all plan -out=planfile --terragrunt-parallelism 4 --terragrunt-no-auto-init";
      tgpau = "terragrunt run-all plan -out=planfile --terragrunt-source-update --terragrunt-parallelism 4 --terragrunt-no-auto-init";
      tgpu = "terragrunt plan -out=planfile --terragrunt-source-update --terragrunt-no-auto-init";
      tgr = "terragrunt refresh --terragrunt-no-auto-init";
      tgs = "terragrunt show -json planfile --terragrunt-no-auto-init | jq . | less";
      tgt = "terragrunt taint --terragrunt-no-auto-init";

    };
    dirHashes = {
      mintel = "/data/gitlab.com/mintel";
      satoshi = "/data/gitlab.com/mintel/satoshi";
    };
    oh-my-zsh = {
      enable = true;
      plugins = [
        "aws"
        "direnv"
        "git"
        "kube-ps1"
        "kubectl"
        "timer"
      ];
      theme = "robbyrussell";
    };
  };

  # programs.vscode = {
  #   enable = true;
  # };

  # This value determines the home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update home Manager without changing this value. See
  # the home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "25.05";

  # Let home-manager install and manage itself
  programs.home-manager.enable = true;
}
