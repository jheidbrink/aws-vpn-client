This is a Bash script which connects to an AWS client VPN.

It's based on https://github.com/aws-vpn-client/aws-vpn-client from Alex Samorukov - I just packaged this in Nix,
and used `nc` instead of a proper webserver to read the SAML response.
For a blogpost see https://smallhacks.wordpress.com/2020/07/08/aws-client-vpn-internals/

The patches were downloaded from https://amazon-source-code-downloads.s3.amazonaws.com/aws/clientvpn/openvpn-2.6.12-aws-1.tar.gz
and adapted to 2.6.19. The patch for 2.6.12 is also stored in this repo for reference.

## Connecting to AWS Client VPN

Install the Nix package manager, then run
```bash
nix run github.com:jheidbrink/aws-vpn-client -- <your-aws-client-vpn-config-file>
```

 Alternatively you can manually build the patched openvpn and use the resulting binary in the script.
 Note that the script requires netcat-bsd, if you want to use it with GNU netcat, you have to adapt the parameters.


 ## License ##

Licensed under MIT with vendored GPL parts, see LICENSE file

