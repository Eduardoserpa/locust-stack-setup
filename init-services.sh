#!/bin/bash
set -euo pipefail

sudo cp -f -r matrix-locust-mod/. matrix-locust/
./setup-matrix-stack.sh init

# ./setup-matrix-stack.sh start
