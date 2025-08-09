#!/bin/sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo $SCRIPT_DIR

# Ensure script runs with appropriate privileges
if [ $(id -u) -ne 0 ]; then
    echo "This script must be run as root or with sudo."
    exit 1
fi

echo -n "Bitte Domain eingeben: "
read domain

# Check if a domain argument is provided
if [ -z $domain ]; then
    echo "Usage: $0 <your-domain>"
    exit 1
fi

# Mapping-Tabelle: "Quelle|Ziel"
FILES="
+TARGETS|/usr/local/opnsense/service/templates/OPNsense/Unbound/+TARGETS
expert.conf|/usr/local/opnsense/service/templates/OPNsense/Unbound/expert.conf
access-list-PD.conf|/usr/local/opnsense/service/templates/OPNsense/Unbound/access-list-PD.conf
update-kea-dhcp6.sh|/usr/local/sbin/update-kea-dhcp6.sh 
mylocaldomain.conf|/usr/local/opnsense/service/templates/OPNsense/Unbound/mylocaldomain.conf
"

for ENTRY in $FILES; do
    SRC=$(echo "$ENTRY" | cut -d"|" -f1)
    DEST=$(echo "$ENTRY" | cut -d"|" -f2)

    echo "Kopiere $SRC → $DEST"
    mkdir -p "$(dirname "$DEST")" || exit 1
    cp "$SCRIPT_DIR/$SRC" "$DEST" || exit 1
done

sed -i '' "s/@@domain@@/${domain}/g" /usr/local/opnsense/service/templates/OPNsense/Unbound/mylocaldomain.conf 

# Generate the templates
configctl template reload OPNsense/Unbound

# Check if the configuration is valid
configctl unbound check

# Restart Unbound service
configctl unbound restart
