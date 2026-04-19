{
  description = "AWS VPN client script";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];

      forAllSystems = f:
        nixpkgs.lib.genAttrs supportedSystems (system: f {
          pkgs = nixpkgs.legacyPackages.${system};
        });
    in
    {
      packages = forAllSystems ({ pkgs }: let
        openssl-aws = pkgs.callPackage ./openssl-aws.nix { };
        openvpn-aws = pkgs.callPackage ./openvpn-aws.nix { inherit openssl-aws; };
        aws-vpn-client = pkgs.callPackage ./aws-vpn-client.nix { inherit openvpn-aws; };
      in {
        inherit openssl-aws openvpn-aws aws-vpn-client;
        default = aws-vpn-client;
      });
    };
}
