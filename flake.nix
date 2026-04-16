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
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      latest = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      homeConfigurations = {
        bbrockway = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./work-laptop.nix ];
          extraSpecialArgs = {
            inherit latest;
          };
        };
        vagrant = home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [ ./vagrant.nix ];
          extraSpecialArgs = {
            inherit latest;
          };
        };
      };
    };
}
