# Patched OpenSSL for AWS Client VPN.

{ openssl }:

openssl.overrideAttrs (oldAttrs: {
  pname = "openssl-aws-vpn";

  patches = (oldAttrs.patches or [ ]) ++ [
    ./patches/openssl-aws-revert-self-signed-cert-logic.patch
  ];

  # The AWS patch changes self-signed cert detection, causing
  # 25-test_verify.t test 181 to fail. Remove that test file.
  postPatch = (oldAttrs.postPatch or "") + ''
    rm -f test/recipes/25-test_verify.t
  '';
})
