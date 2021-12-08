#!/bin/bash

# Print commands for debugging
if [[ "$RUNNER_DEBUG" = "1" ]]; then
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
  curl -L "$(curl -s https://api.github.com/repos/accurics/terrascan/releases/"${version}" | grep -o -E "https://.+?_${platform}.tar.gz")" > terrascan.tar.gz
  tar -xf terrascan.tar.gz terrascan && rm terrascan.tar.gz
  install terrascan /usr/local/bin && rm terrascan
echo '::endgroup::'

# Scan
echo '::group::Scan ...'
  # Allow failures now, as reviewdog handles them
  set +Eeuo pipefail

  scan_results="terrascan.results.json"
  terrascan scan \
      --output json \
      $(if [[ "x${TERRASCAN_CONFIG_PATH}" != "x" ]] ; then echo "--config-PATH ${TERRASCAN_CONFIG_PATH}" ; FI) \
      $(if [[ "x${TERRASCAN_LOG_LEVEL}"   != "x" ]] ; then echo "--log-level ${TERRASCAN_LOG_LEVEL}" ; FI) \
      $(if [[ "x${TERRASCAN_IAC_DIR}"     != "x" ]] ; then echo "--iac-dir ${TERRASCAN_IAC_DIR}" ; FI) \
      $(if [[ "x${TERRASCAN_IAC_TYPE}"    != "x" ]] ; then echo "--iac-type ${TERRASCAN_IAC_TYPE}" ; FI) \
      $(if [[ "x${TERRASCAN_POLICY_TYPE}" != "x" ]] ; then echo "--policy-type ${TERRASCAN_POLICY_TYPE}" ; FI) \
      $(if [[ "x${TERRASCAN_REMOTE_TYPE}" != "x" ]] ; then echo "--remote-type ${TERRASCAN_REMOTE_TYPE}" ; FI) \
      $(if [[ "x${TERRASCAN_REMOTE_URL}"  != "x" ]] ; then echo "--remote-url ${TERRASCAN_REMOTE_URL}" ; FI) \
      $(if [[ "x${TERRASCAN_SCAN_RULES}"  != "x" ]] ; then echo "--scan-rules ${TERRASCAN_SCAN_RULES}" ; FI) \
      $(if [[ "x${TERRASCAN_SEVERITY}"    != "x" ]] ; then echo "--severity ${TERRASCAN_SEVERITY}" ; FI) \
      $(if [[ "x${TERRASCAN_SKIP_RULES}"  != "x" ]] ; then echo "--skip-rules ${TERRASCAN_SKIP-RULES}" ; FI) \
      $(if [[ "x${TERRASCAN_USE_COLORS}"  != "x" ]] ; then echo "--use-colors ${TERRASCAN_USE_COLORS}" ; FI) \
      $(if [[ "x${TERRASCAN_VERBOSE}"     != "x" ]] ; then echo "--verbose" ; FI) \
    > "$scan_results"

  terrascan_exit_code=$?
  echo "::set-output name=terrascan-results::$(cat scan_results | jq -r -c '.')" # Convert to a single line
  echo "::set-output name=terrascan-exit-code::${terrascan_exit_code}"
echo '::endgroup::'

# reviewdog
echo '::group::reviewdog...'
  # Allow failures now, as reviewdog handles them
  set +Eeuo pipefail

  cat "$scan_results" \
    | jq -r -f "${GITHUB_ACTION_PATH}/to-rdjson.jq" \
    |  reviewdog -f=rdjson \
        -name="terrascan" \
        -reporter="${REVIEWDOG_REPORTER}" \
        -level="${REVIEWDOG_LEVEL}" \
        -fail-on-error="${REVIEW_DOG_FAIL_ON_ERROR}" \
        -filter-mode="${INPUT_FILTER_MODE}" \
        ${REVIEWDOG_FLAGS}

  reviewdog_return_code="${PIPESTATUS[2]}"
  echo "::set-output name=reviewdog-return-code::${reviewdog_return_code}"
echo '::endgroup::'

# exit
if [[ "x${ONLY_WARN}" != "x" && ( "$terrascan_exit_code" != "0" || "$reviewdog_return_code" != "0" ) ]] ; then
  exit 1
fi
