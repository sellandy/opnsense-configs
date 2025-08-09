#!/bin/sh

# --- Funktion: Nur re0 + VLANs erkennen ---
get_re0_and_vlans() {
    ifconfig -l | tr ' ' '\n' | grep -E '^(re0|vlan[0-9]+)$'
}


# === Variablen ===
KEA_CONF="/usr/local/etc/kea/subnet6.json"
KEA_BACKUP="/usr/local/etc/kea/subnet6.json.bak"
KEA6_CONF="/usr/local/etc/kea/kea-dhcp6.conf"
KEA_IFS=$(get_re0_and_vlans)
POOL_START=":1000"
POOL_END=":2000"
TMP_CONF="/tmp/kea-dhcp6.conf.tmp"
UNBOUND_ACCESS="/usr/local/opnsense/service/templates/OPNsense/Unbound/access-list-PD.conf"

# === Backup der aktuellen Konfig ===
cp "$KEA_CONF" "$KEA_BACKUP"

# === Header schreiben ===
cat <<EOF > "$TMP_CONF"
 "subnet6": [
EOF

FIRST=1
# === Für jedes Interface Subnetz berechnen ===

  ID=1
  echo "server:" > $UNBOUND_ACCESS

for ENTRY in $KEA_IFS; do
  PHY_IF=$(echo $ENTRY)

  FULL_IPV6=$(ifconfig $PHY_IF | grep 'inet6' | grep -v 'fe80' | grep -v 'fd00' | awk '{print $2}')
  [ -z "$FULL_IPV6" ] && echo "Keine IPv6-Adresse für $PHY_IF gefunden." && continue


  PREFIX=$(echo "$FULL_IPV6" | cut -d: -f1-4)
  [ -z "$PREFIX" ] && echo "Kein IPv6-Prefix für $PHY_IF gefunden." && continue

  # Interface-Adresse für DNS annehmen (z. B. ...::1)
  DNS_SERVER="$FULL_IPV6"

  echo "access-control: $PREFIX::/64 allow" >> $UNBOUND_ACCESS

    [ $FIRST -eq 0 ] && echo "," >> "$TMP_CONF"
  FIRST=0
  cat <<EOF >> "$TMP_CONF"
      {
        "id": $ID,
        "subnet": "$PREFIX::/64",
        "interface": "$PHY_IF",
        "pools": [
          {
            "pool": "$PREFIX:$POOL_START - $PREFIX:$POOL_END"
          }
        ],
        "option-data": [
            {
                "name": "dns-servers",
                "data": "$DNS_SERVER"
            }
        ],
        "rapid-commit": true
      }
EOF

  ID=$((ID + 1 ))
done

# === Footer schreiben ===
cat <<EOF >> "$TMP_CONF"
    ],
EOF

# === Neue Konfiguration übernehmen ===
mv "$TMP_CONF" "$KEA_CONF"

kea-dhcp6 -t "$KEA6_CONF"

echo "Kea DHCPv6-Konfiguration aktualisiert."

keactrl reload

echo "Kea Konfiguration - neu geladen"
configctl template reload OPNsense/Unbound

configctl unbound restart

echo "Unbound ACL - neu geladen"
