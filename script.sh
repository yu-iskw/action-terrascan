#!/bin/bash

# Print commands for debugging
if [[ "$RUNNER_DEBUG" == "1" ]]; then
  set -x
fi

# Fail fast on errors, unset variables, and failures in piped commands
set -Eeuo pipefail

cd "${WORKING_DIRECTORY}" || exit

# Install terrascan
echo '::group::Installing terrascan ...'
# Download and install terrascan
version="${TERRASCAN_VERSION:?}"
platform="${TERRASCAN_PLATFORM:?}"
curl -L "$(curl -s https://api.github.com/repos/accurics/terrascan/releases/"${version}" | grep -o -E "https://.+?_${platform}.tar.gz")" >terrascan.tar.gz
tar -xf terrascan.tar.gz terrascan && rm terrascan.tar.gz
install terrascan /usr/local/bin && rm terrascan
echo "terrascan is installed at $(which terrascan)."
echo '::endgroup::'

# Scan
echo '::group::Scan ...'
# Allow failures now, as reviewdog handles them
set +Eeuo pipefail

scan_results="terrascan.results.json"
echo 1
# shellcheck disable=SC2046
terrascan scan \
  --output json \
  $(if [[ "x${TERRASCAN_CONFIG_PATH}" != "x" ]]; then echo "--config-PATH ${TERRASCAN_CONFIG_PATH}"; fi) \
  $(if [[ "x${TERRASCAN_LOG_LEVEL}" != "x" ]]; then echo "--log-level ${TERRASCAN_LOG_LEVEL}"; fi) \
  $(if [[ "x${TERRASCAN_IAC_DIR}" != "x" ]]; then echo "--iac-dir ${TERRASCAN_IAC_DIR}"; fi) \
  $(if [[ "x${TERRASCAN_IAC_TYPE}" != "x" ]]; then echo "--iac-type ${TERRASCAN_IAC_TYPE}"; fi) \
  $(if [[ "x${TERRASCAN_POLICY_TYPE}" != "x" ]]; then echo "--policy-type ${TERRASCAN_POLICY_TYPE}"; fi) \
  $(if [[ "x${TERRASCAN_REMOTE_TYPE}" != "x" ]]; then echo "--remote-type ${TERRASCAN_REMOTE_TYPE}"; fi) \
  $(if [[ "x${TERRASCAN_REMOTE_URL}" != "x" ]]; then echo "--remote-url ${TERRASCAN_REMOTE_URL}"; fi) \
  $(if [[ "x${TERRASCAN_SCAN_RULES}" != "x" ]]; then echo "--scan-rules ${TERRASCAN_SCAN_RULES}"; fi) \
  $(if [[ "x${TERRASCAN_SEVERITY}" != "x" ]]; then echo "--severity ${TERRASCAN_SEVERITY}"; fi) \
  $(if [[ "x${TERRASCAN_SKIP_RULES}" != "x" ]]; then echo "--skip-rules ${TERRASCAN_SKIP-RULES}"; fi) \
  $(if [[ "x${TERRASCAN_USE_COLORS}" != "x" ]]; then echo "--use-colors ${TERRASCAN_USE_COLORS}"; fi) \
  $(if [[ "x${TERRASCAN_VERBOSE}" != "x" ]]; then echo "--verbose"; fi) \
  >"$scan_results"

terrascan_exit_code=$?

echo 2
cat <, "$scan_results"

echo "::set-output name=terrascan-results::$(cat <"$scan_results" | jq -r -c '.')" # Convert to a single line
echo "::set-output name=terrascan-exit-code::${terrascan_exit_code}"

echo 3
set -Eeuo pipefail
echo '::endgroup::'

# reviewdog
echo '::group::reviewdog...'
# Allow failures now, as reviewdog handles them
set +Eeuo pipefail

cat <"$scan_results" |
  jq -r --arg "working_directory" "${WORKING_DIRECTORY:?}" -f "${GITHUB_ACTION_PATH}/to-rdjson.jq" |
  reviewdog -f=rdjson \
    -name="terrascan" \
    -reporter="${REVIEWDOG_REPORTER}" \
    -level="${REVIEWDOG_LEVEL}" \
    -fail-on-error="${REVIEWDOG_FAIL_ON_ERROR}" \
    -filter-mode="${REVIEWDOG_FILTER_MODE}"

reviewdog_return_code="${PIPESTATUS[2]}"
echo "::set-output name=reviewdog-return-code::${reviewdog_return_code}"

set -Eeuo pipefail
echo '::endgroup::'

# exit
if [[ "x${ONLY_WARN}" != "x" && ("$terrascan_exit_code" != "0" || "$reviewdog_return_code" != "0") ]]; then
  exit 1
fi
