#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../terraform"
terraform output -json instance_public_ips | jq -r '.[]' | awk '
BEGIN { print "[app]" }
{ print $1 " ansible_user=ec2-user" }
' > ../ansible/inventory.ini

cat ../ansible/inventory.ini
