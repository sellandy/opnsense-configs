#!/bin/sh

# ===== Dynu / DynDNS2 Einstellungen =====
HOSTNAME="HOST"
USERNAME="username"
PASSWORD="Password"

# WAN Interface mit globaler stabiler IPv6
IPV6_IF="WAN-Interface"

STATE_DIR="/var/db/dynu"
IPV4_FILE="${STATE_DIR}/last_ipv4"
IPV6_FILE="${STATE_DIR}/last_ipv6"
LOG_TAG="dynu-update"

mkdir -p "${STATE_DIR}"

get_ipv4() {
  for url in \
    "https://api4.ipify.org" \
    "https://ipv4.icanhazip.com" \
    "https://ifconfig.me/ip"
  do
    ip="$(/usr/local/bin/curl -4 -s --max-time 10 "$url" | /usr/bin/tr -d '\r\n')"
    echo "$ip" | /usr/bin/grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' && {
      echo "$ip"
      return 0
    }
  done
  return 1
}

get_stable_ipv6() {
  /sbin/ifconfig "${IPV6_IF}" 2>/dev/null | /usr/bin/awk -v suffix="${IPV6_SUFFIX}" '
    $1 == "inet6" {
      ip = $2
      sub(/%.*/, "", ip)

      if (ip ~ /^fe80:/) next
      if (ip ~ /^fc/ || ip ~ /^fd/) next

      low = tolower(ip)
      sfx = tolower(suffix)

      if (low ~ sfx "$") {
        print ip
        exit
      }
    }
  '
}

update_dynu() {
  ip="$1"
  type="$2"

  response="$(/usr/local/bin/curl -s --max-time 20 \
    --user "${USERNAME}:${PASSWORD}" \
    "https://api.dynu.com/nic/update?hostname=${HOSTNAME}&myip=${ip}")"

  /usr/bin/logger -t "${LOG_TAG}" "${type}: ${ip} -> ${response}"
  echo "${response}"
}

# ===== IPv4 aktualisieren =====
IPV4="$(get_ipv4)"
if [ -n "${IPV4}" ]; then
  OLD4=""
  [ -f "${IPV4_FILE}" ] && OLD4="$(cat "${IPV4_FILE}")"

  if [ "${IPV4}" != "${OLD4}" ]; then
    R4="$(update_dynu "${IPV4}" "IPv4")"
    case "${R4}" in
      good*|nochg*) echo "${IPV4}" > "${IPV4_FILE}" ;;
    esac
  fi
else
  /usr/bin/logger -t "${LOG_TAG}" "Keine öffentliche IPv4 gefunden"
fi

# ===== IPv6 aktualisieren =====
IPV6="$(get_stable_ipv6)"
if [ -n "${IPV6}" ]; then
  OLD6=""
  [ -f "${IPV6_FILE}" ] && OLD6="$(cat "${IPV6_FILE}")"

  if [ "${IPV6}" != "${OLD6}" ]; then
    R6="$(update_dynu "${IPV6}" "IPv6")"
    case "${R6}" in
      good*|nochg*) echo "${IPV6}" > "${IPV6_FILE}" ;;
    esac
  fi
else
  /usr/bin/logger -t "${LOG_TAG}" "Keine stabile globale IPv6 auf ${IPV6_IF} gefunden"
fi
