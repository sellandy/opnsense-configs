#!/bin/sh
# Dynu DynDNS Update (OPNsense)
# IPv4: myip=
# IPv6: myipv6=

HOSTNAME="mycharon.freeddns.org"
USERNAME="sellandy"
PASSWORD="DLBV^zJ835scP^pIYh"

IPV6_IF="igc0"
IPV6_SUFFIX="8ea6:82ff:fe71:4649"

STATE_DIR="/var/db/dynu"
IPV4_FILE="${STATE_DIR}/last_ipv4"
IPV6_FILE="${STATE_DIR}/last_ipv6"
LOG_TAG="dynu-update"

# DEBUG=1 => zusätzliche Logger-Ausgaben
DEBUG="${DEBUG:-0}"

mkdir -p "${STATE_DIR}"

log_info() {
  /usr/bin/logger -t "${LOG_TAG}" "$*"
}
log_dbg() {
  [ "${DEBUG}" = "1" ] && /usr/bin/logger -t "${LOG_TAG}" "DEBUG: $*"
}

# Minimal-URL-Encoding: nur ':' für IPv6 erforderlich
enc_ip() {
  echo "$1" | /usr/bin/sed 's/:/%3A/g'
}

validate_ipv6_suffix() {
  # Muss 4 Hextets haben: xxxx:xxxx:xxxx:xxxx (je 1..4 Hex-Zeichen)
  echo "$IPV6_SUFFIX" | /usr/bin/grep -Eq '^[0-9a-fA-F]{1,4}(:[0-9a-fA-F]{1,4}){3}$'
}

get_ipv4() {
  for url in \
    "https://api4.ipify.org" \
    "https://ipv4.icanhazip.com" \
    "https://ifconfig.me/ip"
  do
    log_dbg "get_ipv4: query ${url}"
    ip="$(/usr/local/bin/curl -4 -s --max-time 10 "$url" | /usr/bin/tr -d '\r\n')"
    log_dbg "get_ipv4: raw='${ip}'"
    echo "$ip" | /usr/bin/grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' && {
      echo "$ip"
      return 0
    }
  done
  return 1
}

get_stable_ipv6() {
  # Nimmt globale /64 Adresse vom Interface, nimmt erstes /64 (4 Hextets) und hängt suffix an
  prefix="$(
    /sbin/ifconfig "${IPV6_IF}" 2>/dev/null | /usr/bin/awk '
      $1=="inet6" {
        ip=tolower($2); sub(/%.*/, "", ip)

        # link-local und ULA ignorieren
        if (ip ~ /^fe80:/) next
        if (ip ~ /^(fc|fd)/) next

        # nur globale Adressen mit Prefix-Länge 64
        if ($0 ~ /prefixlen 64/) {
          n=split(ip,a,":")
          if (n>=4) { print a[1] ":" a[2] ":" a[3] ":" a[4]; exit }
        }
      }
    '
  )"

  [ -n "${prefix}" ] || return 1
  echo "${prefix}:${IPV6_SUFFIX}"
}

update_dynu() {
  ip="$1"
  type="$2"   # "IPv4" oder "IPv6"

  [ -n "${ip}" ] || return 1

  enc="$(enc_ip "$ip")"
  if [ "${type}" = "IPv6" ]; then
    param="myipv6"
  else
    param="myip"
  fi

  url="https://api.dynu.com/nic/update?hostname=${HOSTNAME}&${param}=${enc}"
  log_dbg "update_dynu: ${type} ip=${ip} url=${url}"

  response="$(
    /usr/local/bin/curl -s --max-time 20 \
      --user "${USERNAME}:${PASSWORD}" \
      "${url}"
  )"

  /usr/bin/logger -t "${LOG_TAG}" "${type}: ${ip} -> ${response}"
  echo "${response}"
}

# ===== Main =====
log_dbg "main: start"

if ! validate_ipv6_suffix; then
  log_info "ERROR: IPV6_SUFFIX has invalid format: '${IPV6_SUFFIX}'"
  exit 1
fi

# ---- IPv4 ----
IPV4="$(get_ipv4 2>/dev/null)"
if [ -z "${IPV4}" ]; then
  log_info "IPv4: keine öffentliche IPv4 gefunden"
else
  OLD4=""
  [ -f "${IPV4_FILE}" ] && OLD4="$(cat "${IPV4_FILE}" 2>/dev/null)"

  if [ "${IPV4}" != "${OLD4}" ]; then
    resp4="$(update_dynu "${IPV4}" "IPv4")"
    case "${resp4}" in
      good*|nochg*) echo "${IPV4}" > "${IPV4_FILE}" ;;
    esac
  else
    log_dbg "IPv4 unchanged (${IPV4})"
  fi
fi

# ---- IPv6 ----
IPV6="$(get_stable_ipv6 2>/dev/null)"
if [ -z "${IPV6}" ]; then
  log_info "IPv6: kein globaler /64 Prefix auf ${IPV6_IF} gefunden"
else
  OLD6=""
  [ -f "${IPV6_FILE}" ] && OLD6="$(cat "${IPV6_FILE}" 2>/dev/null)"

  if [ "${IPV6}" != "${OLD6}" ]; then
    resp6="$(update_dynu "${IPV6}" "IPv6")"
    case "${resp6}" in
      good*|nochg*) echo "${IPV6}" > "${IPV6_FILE}" ;;
    esac
  else
    log_dbg "IPv6 unchanged (${IPV6})"
  fi
fi

log_dbg "main: end"
