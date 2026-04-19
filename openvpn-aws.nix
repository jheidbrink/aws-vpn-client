# AWS-patched OpenVPN for use with AWS Client VPN.
#
# Re-uses the upstream nixpkgs openvpn package and layers on the AWS
# patches that increase various buffer sizes and change the TLS key
# exchange to use 32-bit length prefixes instead of 16-bit.
#
# The patches originate from:
#   https://amazon-source-code-downloads.s3.amazonaws.com/aws/clientvpn/openvpn-2.6.12-aws-1.tar.gz
#
# The openvpn patch (originally for 2.6.12) has been adapted for 2.6.19
# and is shipped as patches/openvpn-v2.6.19-aws.patch in this repository.

{ openvpn, openssl-aws }:

(openvpn.override { openssl = openssl-aws; }).overrideAttrs (oldAttrs: {
  pname = "openvpn-aws";

  patches = (oldAttrs.patches or [ ]) ++ [
    # AWS Client VPN compatibility: increase buffer sizes for SAML auth tokens,
    # use 32-bit TLS length prefixes, enlarge management interface buffers.
    ./patches/openvpn-v2.6.19-aws.patch
  ];

  postFixup = (oldAttrs.postFixup or "") + ''
    mv $out/bin/openvpn $out/bin/openvpn-aws
  '';

  meta = (oldAttrs.meta or { }) // {
    description = "OpenVPN with AWS Client VPN patches (increased buffer sizes, 32-bit TLS length prefixes)";
    homepage = "https://aws.amazon.com/vpn/client-vpn-download/";
    mainProgram = "openvpn-aws";
  };
})
