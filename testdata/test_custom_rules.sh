#!/bin/bash

# A function to check if the given rule ID exists in the scan results.
function contains_violation() {
  local scan_results="${1:?}"
  local rule_id="${2:?}"
  echo "$scan_results" | jq -r ".results.violations | select(.[].rule_id == \"${rule_id}\") | length"
}
export -f contains_violation

set +Eeuo pipefail

scan_results=$(terrascan scan --policy-path ./policy --iac-type terraform --iac-dir . --output json --use-colors f)

# Test AC_gcp_IAM_custom_001
if [[ "$(contains_violation "$scan_results" "AC_gcp_IAM_custom_001")" != "1" ]] ; then
  echo "[ERROR] No violations on AC_gcp_IAM_custom_001"
  exit 1
else
  echo "[PASSED] AC_gcp_IAM_custom_001"
fi

set -Eeuo pipefail
