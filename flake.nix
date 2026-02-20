{
  description = "My Home Manager config";
  inputs = {
    nixpkgs.url = "nixpkgs/release-25.11";
    nixpkgs-unstable.url = "nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      ...
    }:
    let
      lib = nixpkgs.lib;
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfreePredicate =
          pkg:
          builtins.elem (lib.getName pkg) [
            "claude-code"
            "code-cursor-fhs"
            "cursor"
            "terraform"
            "vscode"
            "warp-terminal"
          ];
      };
      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfreePredicate =
          pkg:
          builtins.elem (lib.getName pkg) [
            "claude-code"
            "code-cursor-fhs"
            "cursor"
            "terraform"
            "vscode"
            "warp-terminal"
          ];
      };
    in
    {
      homeConfigurations = {
        bbrockway = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./home.nix ];
          extraSpecialArgs = {
            inherit pkgs-unstable;
          };
        };
        vagrant = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./vagrant.nix ];
          extraSpecialArgs = {
            inherit pkgs-unstable;
          };
        };
      };
    };
}
