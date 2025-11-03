{
  description = "Develop Simple Elastic Stack on Nix";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs lib.systems.flakeExposed;
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell rec {
            # These are tools you want available on your PATH
            packages = with pkgs; [
              openssl_3
            ];
          };
        }
      );
    };
}
