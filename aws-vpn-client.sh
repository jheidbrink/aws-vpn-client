#!/usr/bin/env bash

set -euo pipefail

function log() {
  >&2 echo "$@"
}

patched_openvpn_binary=openvpn-aws
saml_redirect_url_port=35001
update_resolv_conf=$(which update-resolv-conf) # in sudo context the PATH is lost, so resolve it here

original_vpn_config_file="$1"
if [ -z "${original_vpn_config_file:-}" ]
then
  log "Usage: $0 <aws-vpn-config-file>"
  exit 1
fi

remote_line=$(grep -E '^remote [^ ]+ [0-9]+$' "$original_vpn_config_file")
vpn_host_unprefixed=$(echo "$remote_line" | cut -d ' ' -f 2)
vpn_port=$(echo "$remote_line" | cut -d ' ' -f 3)
log "Extracted host ${vpn_host_unprefixed} and port ${vpn_port} from config"

log "AWS uses remote-random-hostname setting, we take care of this by prefixing with random prefix"
random_prefix=$(openssl rand -hex 12)
vpn_host_prefixed="${random_prefix}.${vpn_host_unprefixed}"
log "Host with prefix is $vpn_host_prefixed"

temporary_folder=$(mktemp -d)
temporary_vpn_config_file="${temporary_folder}/adapted-openvpn-config"

function cleanup() {
  log "Removing temporary openvpn config file $temporary_folder"
  rm -rf "$temporary_folder"
}
trap cleanup EXIT

log "Writing temporary openvpn config to $temporary_vpn_config_file"
< "$original_vpn_config_file" sed \
  -e '/^remote /d' \
  -e '/^remote-random-hostname/d' \
  -e '/^auth-user-pass/d' \
  -e '/^auth-federate/d' \
  -e '/^auth-retry interact/d' \
  > "$temporary_vpn_config_file"

# resolve hostname to IP, as we have to keep persistent ip address
log "Resolving $vpn_host_prefixed"
ip=$(dig a +short "$vpn_host_prefixed" | head -n1)
log "IP is $ip"

log "Getting SAML redirect URL from the AUTH_FAILED response"
ovpn_out=$($patched_openvpn_binary --config "$temporary_vpn_config_file" --verb 3 \
     --remote "$ip" "$vpn_port" \
     --auth-user-pass <( printf "%s\n%s\n" "N/A" "ACS::$saml_redirect_url_port" ) \
    2>&1 | grep AUTH_FAILED,CRV1)

url=$(echo "$ovpn_out" | grep -Eo 'https://.+')
log "Opening $url in browser and waiting for the SAML response..."

unameOut="$(uname -s)"
case "${unameOut}" in
    # at some point launching firefox became blocking and I had to append the `&>/dev/null &`
    Linux*)     xdg-open "$url" &>/dev/null &;;
    Darwin*)    open "$url";;
    *)          echo "Could not determine 'open' command for OS ${unameOut}, only Linux and Darwin are supported"; exit 1;;
esac

# Listen for the browser's SAML POST with netcat.
# nc receives the HTTP request on stdout; we pipe in the HTTP response
# so the browser gets a proper reply and closes the connection.
saml_redirect_url_http_request=$(printf 'HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 53\r\nConnection: close\r\n\r\nGot SAMLResponse field, it is now safe to close this window\n' \
  | nc -l 127.0.0.1 "$saml_redirect_url_port")

# Extract the URL-encoded SAMLResponse value from the POST body.
# The body contains: SAMLResponse=<url-encoded-value> (possibly among other fields)
saml_response=$(printf '%s' "$saml_redirect_url_http_request" | grep -o 'SAMLResponse=[^& ]*' | head -1 | cut -d= -f2-)

if [[ -z "$saml_response" ]]; then
  echo "Failed to capture SAML response" >&2
  exit 1
fi

vpn_sid=$(echo "$ovpn_out" | awk -F : '{print $7}')
log "vpn_sid is $vpn_sid"

credential_fifo="${temporary_folder}/credentials"
printf '%s\n%s\n' 'N/A' "CRV1::${vpn_sid}::${saml_response}" > "$credential_fifo"

# --script-security 2  Allow OpenVPN to call external scripts (default is 1
#                       which blocks all script execution).
# --up / --down         Run update-resolv-conf when the tunnel comes up/down.
#                       The script reads OpenVPN's foreign_option_* env vars
#                       (e.g. "dhcp-option DNS 10.0.0.2") and calls resolvconf
#                       to add/remove VPN DNS servers in /etc/resolv.conf.
# --down-pre            Run the --down script *before* the TUN device is closed,
#                       so the script can still identify the interface name to
#                       remove the correct resolvconf entry.
exec sudo "$patched_openvpn_binary" --config "$temporary_vpn_config_file" \
    --verb 3 --auth-nocache --inactive 3600 \
    --remote "$ip" "$vpn_port" \
    --script-security 2 \
    --up "$update_resolv_conf" \
    --down "$update_resolv_conf" \
    --down-pre \
    --auth-user-pass "$credential_fifo"
