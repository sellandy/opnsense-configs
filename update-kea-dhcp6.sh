#!/bin/sh
# --- Update KEA DHCPv6 Subnets bei PD-Wechsel ---

LOGGER="logger -t update-kea subnet"
STATEFILE="/tmp/last_ipv6_pd"

# --- Pfade KEA / Unbound ---
KEA_MASTER="/usr/local/etc/kea/kea-dhcp6.conf"
KEA_CONF="/usr/local/etc/kea/subnet6.json"
KEA_BACKUP="/usr/local/etc/kea/subnet6.json.bak"
DHCP6_LEASE="/var/db/kea/kea-leases6.csv"
TMP_CONF="/tmp/kea-dhcp6.conf.tmp"
POOL_START="1000"
POOL_END="2000"

# --- Backup der aktuellen Konfiguration ---
cp "$KEA_CONF" "$KEA_BACKUP"

# --- Track-Interfaces automatisch ermitteln ---
KEA_IFS=$(ifconfig -l | tr ' ' '\n' | grep -E '^(vlan[0-9]+)$')


[ -z "$KEA_IFS" ] && { $LOGGER "Keine Track-VLANs gefunden, Abbruch."; exit 1; }

# --- Header schreiben ---
cat <<EOF > "$TMP_CONF"
 "subnet6": [
EOF

FIRST=1
ID=1

for PHY_IF in $KEA_IFS; do
    # IPv6 für Interface holen (globale Adresse, keine fe80 / fd00)
    FULL_IPV6=$(ifconfig $PHY_IF | awk '/inet6/ && !/fe80/ && !/fd/ && !/temporary/ && !/deprecated/ {print $2}')
    [ -z "$FULL_IPV6" ] && $LOGGER "Keine globale IPv6 auf $PHY_IF gefunden." && continue

    # /64 Subnetz extrahieren
    PREFIX=$(echo "$FULL_IPV6" | cut -d: -f1-4)
    [ -z "$PREFIX" ] && $LOGGER "Kein Präfix auf $PHY_IF gefunden" && continue

    # Interface-Adresse für DNS annehmen
    DNS_SERVER="$FULL_IPV6"

    # Komma zwischen Subnetzen (nicht vor erstem)
    [ $FIRST -eq 0 ] && echo "," >> "$TMP_CONF"
    FIRST=0

    # JSON Subnet schreiben
    cat <<EOF >> "$TMP_CONF"
      {
        "id": $ID,
        "subnet": "$PREFIX::/64",
        "interface": "$PHY_IF",
        "pools": [
          { "pool": "$PREFIX::$POOL_START-$PREFIX::$POOL_END" }
        ],
        "option-data": [
          { "name": "dns-servers", "data": "$DNS_SERVER" }
        ],
        "rapid-commit": true
      }
EOF

    ID=$((ID + 1))
done

# --- Footer schreiben ---
#cat <<EOF >> "$TMP_CONF"
#    ],
#EOF

# --- ULA-Subnets statisch anhängen ---
cat <<EOF >> "$TMP_CONF"
,
      {
        "id": 101,
        "subnet": "fda0:c38c:820a:fff0::/64",
        "interface": "igc1",
        "pools": [
          { "pool": "fda0:c38c:820a:fff0::${POOL_START}-fda0:c38c:820a:fff0::${POOL_END}" }
        ],
        "option-data": [
          { "name": "dns-servers", "data": "fda0:c38c:820a:fff0::1" }
        ],
        "rapid-commit": true
      },
      {
        "id": 102,
        "subnet": "fda0:c38c:820a:fff1::/64",
        "interface": "vlan04",
        "pools": [
          { "pool": "fda0:c38c:820a:fff1::${POOL_START}-fda0:c38c:820a:fff1::${POOL_END}" }
        ],
        "option-data": [
          { "name": "dns-servers", "data": "fda0:c38c:820a:fff1::1" }
        ],
        "rapid-commit": true
      },
      {
        "id": 103,
        "subnet": "fda0:c38c:820a:fff3::/64",
        "interface": "vlan02",
        "pools": [
          { "pool": "fda0:c38c:820a:fff3::${POOL_START}-fda0:c38c:820a:fff3::${POOL_END}" }
        ],
        "option-data": [
          { "name": "dns-servers", "data": "fda0:c38c:820a:fff3::1" }
        ],
        "rapid-commit": true
      },
      {
        "id": 104,
        "subnet": "fda0:c38c:820a:fff4::/64",
        "interface": "vlan01",
        "pools": [
          { "pool": "fda0:c38c:820a:fff4::${POOL_START}-fda0:c38c:820a:fff4::${POOL_END}" }
        ],
        "option-data": [
          { "name": "dns-servers", "data": "fda0:c38c:820a:fff4::1" }
        ],
        "rapid-commit": true
      },
      {
        "id": 105,
        "subnet": "fda0:c38c:820a:fff5::/64",
        "interface": "vlan05",
        "pools": [
          { "pool": "fda0:c38c:820a:fff5::${POOL_START}-fda0:c38c:820a:fff5::${POOL_END}" }
        ],
        "option-data": [
          { "name": "dns-servers", "data": "fda0:c38c:820a:fff5::1" }
        ],
        "rapid-commit": true
      },
      {
        "id": 106,
        "subnet": "fda0:c38c:820a:fff6::/64",
        "interface": "vlan06",
        "pools": [
          { "pool": "fda0:c38c:820a:fff6::${POOL_START}-fda0:c38c:820a:fff6::${POOL_END}" }
        ],
        "option-data": [
          { "name": "dns-servers", "data": "fda0:c38c:820a:fff6::1" }
        ],
        "rapid-commit": true
      }
    ],
EOF


# --- Prüfen, ob PD sich geändert hat (erste IPv6 eines VLANs)
# fallback (falls Script manuell läuft)
FIRST_IF=$(echo "$KEA_IFS" | head -n1)
PD_PREFIX=$(ifconfig $FIRST_IF | awk '/inet6/ && !/fe80/ && !/fd/ {print $2}' | head -n1 | cut -d: -f1-4)

OLD_PD=$(cat $STATEFILE 2>/dev/null)
if [ "$PD_PREFIX" = "$OLD_PD" ]; then
    $LOGGER "PD unverändert ($PD_PREFIX::/64), KEA nicht neu laden."
    exit 0
fi
$LOGGER "PD geändert: $OLD_PD -> $PD_PREFIX::/64"
echo "$PD_PREFIX" > $STATEFILE

# --- Neue Konfiguration übernehmen ---
mv "$TMP_CONF" "$KEA_CONF"

# KEA prüfen und reloaden
kea-dhcp6 -t "$KEA_MASTER"
keactrl reload
$LOGGER "KEA DHCPv6-Konfiguration pruefen und neu laden"
