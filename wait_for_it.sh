#!/usr/bin/env bash

function pod_status {
  local status=""
  for i in $(kubectl get pod --selector app.kubernetes.io/instance=cqai -n cqai-system -o json | jq -r '.items[] | .status.containerStatuses[]? | .ready|tostring' ); do
    status+="${i} "
  done
  echo "${status}"
}

secs=900 # 15 mins
echo -n "Waiting on CQAI ."
while [[ "$(pod_status)" =~ "false" ]]; do
  if [ "$secs" -eq 0 ]; then
    echo "timeout."
    exit 1
  fi

  : $((secs--))
  echo -n "."
  sleep 1
done
echo
echo "Helm deployment reports ready..."
