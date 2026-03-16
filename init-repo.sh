#!/bin/bash
set -euo pipefail

# # Clonando ou atualizando os repositórios necessários
# echo "➕Cloning or updating Matrix Synapse repo"
# clone_result=$(git clone git@github.com:element-hq/synapse.git)

# directory_name=$(echo "$clone_result" | cut -d"'" -f2 | cut -d"'" -f2)
# echo directory_name

git config advice.addIgnoredFile false
echo "➕Cloning or updating Matrix Locust repo"
git clone git@github.com:circles-project/matrix-locust.git
# echo "➕Cloning or updating Matrix Synapse repo"
# git clone git@github.com:element-hq/synapse.git

# echo "➕Cloning or updating OpenTelemetry Demo repo"
# git clone https://github.com/open-telemetry/opentelemetry-demo.git
# echo "➕Cloning or updating OpenTelemetry Collector repo"
# git clone git@github.com:open-telemetry/opentelemetry-collector.git
# echo "➕Cloning or updating Jaeger repo"
# git clone git@github.com:jaegertracing/jaeger.git
# echo "➕Cloning or updating Prometheus repo"
# git clone git@github.com:prometheus/prometheus.git

# # Iniciando os componentes em containers separados
# echo "Starting Matrix Synapse from docker compose"
# docker compose -f matrix-docker-ansible-deploy/docker-compose.yml up --force-recreate --remove-orphans --detach
# echo "Starting OpenTelemetry Demo from docker compose" 
# docker compose -f opentelemetry-demo/docker-compose.yml up --force-recreate --remove-orphans --detach
