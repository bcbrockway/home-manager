# Sync Mintel claude-code-plugins into ~/.cursor/skills (see that repo README, Cursor IDE).
{ config, lib, pkgs, ... }:
let
  repoDir = "${config.home.homeDirectory}/.local/share/claude-code-plugins";
  skillsDir = "${config.home.homeDirectory}/.cursor/skills";
  cloneUrl = "git@gitlab.com:mintel/satoshi/tools/claude-code-plugins.git";
  pathEnv = lib.makeBinPath [
    pkgs.git
    pkgs.openssh
    pkgs.coreutils
  ];
  # Do not read ~/.ssh/config: a broken or legacy Host entry (e.g. PubkeyAcceptedKeyTypes
  # including ssh-dss) makes ssh exit before git can connect, which aborts home-manager switch.
  gitSshCommand = "${lib.getExe pkgs.openssh} -F /dev/null";
in
{
  home.activation.syncMintelCursorSkills = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    set -eu
    # Prepend tools; do not replace PATH — this activation runs inline in HM's bash
    # activate script, and a minimal PATH would drop nix-store for the GC-root step
    # that runs immediately after this block (exit 127 otherwise).
    export PATH=${lib.escapeShellArg pathEnv}:''$PATH
    export GIT_SSH_COMMAND=${lib.escapeShellArg gitSshCommand}
    REPO=${lib.escapeShellArg repoDir}
    SKILLS=${lib.escapeShellArg skillsDir}
    url=${lib.escapeShellArg cloneUrl}

    if [ ! -d "$REPO/.git" ]; then
      $DRY_RUN_CMD mkdir -p "$(dirname "$REPO")"
      $DRY_RUN_CMD git clone "$url" "$REPO"
    fi

    if [ -d "$REPO/.git" ]; then
      $DRY_RUN_CMD git -C "$REPO" pull --ff-only || true
      $DRY_RUN_CMD mkdir -p "$SKILLS"
      # POSIX sh (no bash shopt): if the glob matches nothing, keep one iteration with
      # a non-directory path and skip it.
      for skill in "$REPO"/plugins/*/skills/*/; do
        [ -d "$skill" ] || continue
        base=$(basename "$skill")
        $DRY_RUN_CMD ln -sfn "$skill" "$SKILLS/$base"
      done
    fi
  '';
}
