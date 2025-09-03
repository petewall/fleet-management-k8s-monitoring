#!/usr/bin/env bash

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

pipelineNameToSync=$1

fleetManagementFile="${SCRIPT_DIR}/fleet-management.yaml"
if [ ! -f "${fleetManagementFile}" ]; then
  echo "${fleetManagementFile} not found!"
  echo "Try running make pipelines/fleet-management.yaml"
  exit 1
fi

host=$(yq eval '.host' "${fleetManagementFile}")
username=$(yq eval '.username' "${fleetManagementFile}")
password=$(yq eval '.password' "${fleetManagementFile}")

pipelinesFile="${SCRIPT_DIR}/pipelines.yaml"
if [ ! -f "${pipelinesFile}" ]; then
  echo "${pipelinesFile} not found!"
  exit 1
fi

numPipelines=$(yq eval '.pipelines | length' "${pipelinesFile}")
for i in $(seq 0 $((numPipelines - 1))); do
  pipelineName=$(yq eval ".pipelines[$i].name" "${pipelinesFile}")
  if [ -n "${pipelineNameToSync}" ] && [ "${pipelineName}" != "${pipelineNameToSync}" ]; then
    continue
  fi
  echo "Syncing pipeline: ${pipelineName}"

  pipelineMatchers=$(yq eval --output-format json --indent 0 ".pipelines[$i].matchers" "${pipelinesFile}")
  pipelineFilename=$(yq eval ".pipelines[$i].file" "${pipelinesFile}")
  pipelineFile="${SCRIPT_DIR}/${pipelineFilename}"
  if [ ! -f "${pipelineFile}" ]; then
    echo "Pipeline file ${pipelineFile} not found!"
    exit 1
  fi

  upsertPipelineRequestBody=$(
    jq --null-input \
      --arg name "${pipelineName}" \
      --arg contents "$(cat "${pipelineFile}")" \
      --argjson matchers "${pipelineMatchers}" \
      --argjson enabled true \
     '.pipeline = {name: $name, contents: $contents, matchers: $matchers, enabled: $enabled}')

  curl -X POST \
    --header "Content-Type: application/json" \
    --user "${username}:${password}" \
    --data "${upsertPipelineRequestBody}" \
    "${host}/pipeline.v1.PipelineService/UpsertPipeline" \
    --silent --show-error --fail-with-body

    sleep 1
done
