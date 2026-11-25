#!/usr/bin/env bash
# Verifies every built-in policy/initiative GUID referenced in modules/policy/*.tf
# exists in your cloud and prints its display name so you can eyeball it.
set -uo pipefail
cd "$(dirname "$0")/.."
rc=0
grep -ohE '\$\{local\.(pd|ps)\}/[0-9a-f-]{36}' modules/policy/assignments.tf | sort -u | while read -r line; do
  kind=${line#\$\{local.}; kind=${kind%%\}*}
  guid=${line##*/}
  if [ "$kind" = "ps" ]; then
    name=$(az policy set-definition show --name "$guid" --query displayName -o tsv 2>/dev/null)
  else
    name=$(az policy definition show --name "$guid" --query displayName -o tsv 2>/dev/null)
  fi
  if [ -n "$name" ]; then printf 'OK       %s  %s\n' "$guid" "$name"
  else printf 'MISSING  %s  (%s)\n' "$guid" "$kind"; rc=1; fi
done
exit $rc
