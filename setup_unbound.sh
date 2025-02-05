#!/bin/sh

# Define file paths
targets_file="/usr/local/opnsense/service/templates/OPNsense/Unbound/+TARGETS"
template_file="/usr/local/opnsense/service/templates/OPNsense/Unbound/private_domains.conf"
expert_template_file="/usr/local/opnsense/service/templates/OPNsense/Unbound/expert.conf"
generated_file="/usr/local/etc/unbound.opnsense.d/private_domains.conf"
generated_expert_file="/usr/local/etc/unbound.opnsense.d/expert.conf"

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

# Create the targets file with required content
echo "private_domains.conf:/usr/local/etc/unbound.opnsense.d/private_domains.conf" > "$targets_file"
echo "expert.conf:/usr/local/etc/unbound.opnsense.d/expert.conf" >> "$targets_file"

# Create the private domains template file
cat <<EOF > "$template_file"
server:
  local-data: "$DOMAIN. 3600 IN SOA ns1.dynu.com. administrator.dynu.com. 44196965 1800 300 86400 1800"
EOF

# Create the expert configuration template file
cat <<EOF > "$expert_template_file"
server:
  #  domain-insecure: "onion"
  #  private-domain: "onion"
  local-zone: "onion." nodefault

  # Reduce EDNS reassembly buffer size.
  edns-buffer-size: 1232

  # Don't use Capitalization randomization as it known to cause DNSSEC issues sometimes
  use-caps-for-id: no

  # Trust glue only if it is within the server's authority
  harden-glue: yes
EOF

# Generate the templates
configctl template reload OPNsense/Unbound

# Display the generated files
cat "$generated_file"
cat "$generated_expert_file"

# Check if the configuration is valid
configctl unbound check

# Restart Unbound service
configctl unbound restart
