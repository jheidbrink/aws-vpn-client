{ writeShellApplication
, openvpn-aws          # the patched openvpn from openvpn-aws.nix
, openssl
, dnsutils             # provides `dig`
, netcat-openbsd       # provides `nc`
, xdg-utils            # provides `xdg-open`
, update-resolv-conf   # provides the up/down script for /etc/resolv.conf DNS updates
, coreutils
, gnused
, gnugrep
, gawk
}:

writeShellApplication {
  name = "aws-vpn-client";

  runtimeInputs = [
    openvpn-aws
    openssl
    dnsutils
    netcat-openbsd
    xdg-utils
    coreutils
    gnused
    gnugrep
    gawk
  ];

  text = ''
    export PATH="${update-resolv-conf}/libexec/openvpn:$PATH"
  '' + builtins.readFile ./aws-vpn-client.sh;
}
