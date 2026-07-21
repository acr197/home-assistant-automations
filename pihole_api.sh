#!/bin/sh
# Pi-hole v6 API helper for Home Assistant (sensor + dashboard button).
# The API requires a login session, so this script authenticates with the app
# password stored in secrets.yaml (key: pihole_app_password), caches the session
# id in /tmp, reuses it across calls, and re-authenticates once when it expires.
# No secrets live in this file, so it is safe to commit.
#
# Usage: pihole_api.sh status             prints {"blocking":"enabled","timer":null,...}
#        pihole_api.sh disable <seconds>  pause blocking; Pi-hole re-enables itself after <seconds>
#        pihole_api.sh enable             resume blocking now

API="http://192.168.0.250:8080/api"
SID_FILE="/tmp/pihole_sid"

# Read the app password from secrets.yaml at runtime (strip quotes and CR)
get_password() {
  sed -n 's/^pihole_app_password:[[:space:]]*//p' /config/secrets.yaml | tr -d '"' | tr -d "'" | tr -d '\r'
}

# Log in and cache a fresh session id
login() {
  pw=$(get_password)
  [ -z "$pw" ] && return 1
  resp=$(curl -s -m 5 -X POST "$API/auth" -H "Content-Type: application/json" --data "{\"password\":\"$pw\"}")
  sid=$(printf '%s' "$resp" | sed -n 's/.*"sid":[[:space:]]*"\([^"]*\)".*/\1/p')
  [ -n "$sid" ] && printf '%s' "$sid" > "$SID_FILE"
}

# One API call using the cached session id; prints body, then HTTP code on the last line
call() {
  sid=""
  [ -f "$SID_FILE" ] && sid=$(cat "$SID_FILE")
  if [ -n "$3" ]; then
    curl -s -m 5 -w '\n%{http_code}' -X "$1" "$API/$2" -H "Content-Type: application/json" -H "X-FTL-SID: $sid" --data "$3"
  else
    curl -s -m 5 -w '\n%{http_code}' -X "$1" "$API/$2" -H "X-FTL-SID: $sid"
  fi
}

# Call the API, re-authenticating once if the cached session has expired
request() {
  out=$(call "$1" "$2" "$3")
  code=$(printf '%s' "$out" | tail -n 1)
  if [ "$code" = "401" ]; then
    login
    out=$(call "$1" "$2" "$3")
  fi
  printf '%s\n' "$out" | sed '$d'
}

case "$1" in
  status)  request GET "dns/blocking" ;;
  disable) request POST "dns/blocking" "{\"blocking\": false, \"timer\": ${2:-900}}" ;;
  enable)  request POST "dns/blocking" '{"blocking": true}' ;;
  *) echo "usage: $0 status|disable <seconds>|enable" >&2; exit 1 ;;
esac
