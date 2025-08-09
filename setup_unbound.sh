#!/bin/sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo $SCRIPT_DIR

# Ensure script runs with appropriate privileges
if [ $(id -u) -ne 0 ]; then
    echo "This script must be run as root or with sudo."
    exit 1
fi

# Check if a domain argument is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <your-domain>"
    exit 1
fi

echo "$1"
exit 1

# Mapping-Tabelle: "Quelle|Ziel"
FILES="
+TARGETS|/usr/local/opnsense/service/templates/OPNsense/Unbound/+TARGETS
expert.conf|/usr/local/etc/unbound.opnsense.d/expert.conf
access-list-PD.conf:|/usr/local/etc/unbound.opnsense.d/access-list-PD.conf
mylocaldomain.conf:/usr/local/etc/unbound.opnsense.d/mylocaldomain.conf
"

for ENTRY in $FILES; do
    SRC=$(echo "$ENTRY" | cut -d"|" -f1)
    DEST=$(echo "$ENTRY" | cut -d"|" -f2)

    echo "Kopiere $SRC → $DEST"
    mkdir -p "$(dirname "$DEST")" || exit 1
    cp "$SCRIPT_DIR/$SRC" "$DEST" || exit 1
done

# Generate the templates
configctl template reload OPNsense/Unbound

# Check if the configuration is valid
configctl unbound check

# Restart Unbound service
configctl unbound restart
