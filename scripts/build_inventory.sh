#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../terraform"
terraform output -json instance_public_ips | jq -r '.[]' | awk '
BEGIN { print "[app]" }
{ print $1 " ansible_user=ec2-user" }
' > ../ansible/inventory.ini

HOSTS=$(grep -c 'ansible_user' ../ansible/inventory.ini || true)
if [ "$HOSTS" -eq 0 ]; then
  echo "Error: No hosts found in inventory. Terraform output may be empty." >&2
  exit 1
fi

echo "Inventory built with $HOSTS host(s):"
cat ../ansible/inventory.ini
