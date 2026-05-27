# locust-stack-setup
## Project
The goal of the project is to run a simulation of Synapse Matrix and extract telemetry data through OpenTelemetry to assess the possible bottlenecks in performance that could stem from the synchronization processes that Synapse has to perform in a server with average activity.

The containers are orchestrated by a `docker-compose.yml` file, which is called by the `setup-matrix-stack.sh` script, but it should be enough to run `init-repo.sh`and then `reset-containers.sh` for the project to work.

Matrix Locust is responsible for simulating activity on Synapse. The streams of commands issued by Locust are handled by a Nginx reverse proxy, which divides the tasks by type among the Synapse workers.

On the end of the observability stack, OpenTelemetry data feeds Prometheus, Jaeger and Grafana with information that can be analyzed later.

## Folders
The `data` folder holds persistent data that may be used by the docker containers.

The `config` folder holds most configuration files used inside the containers.

The exception is `matrix-locust-mod`, which has to be copied into `matrix-locust` (copy of Github repo for Locust) for the changes to take effect.

The `not-in-use` folder can have copies of GitHub repos that may hold useful information for debugging. Specially Synapse.

## Dependencies
Install docker compose, Git/SSH and other relevant dependencies based on the instructions documented here for your specific distribution: https://docs.docker.com/compose/install/linux/
`sudo apt install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`
Add the current user to the docker group so the commands can be executed without `sudo`
`sudo groupadd docker && sudo usermod -aG docker ${USER}`
`newgrp docker`

## Starting or restarting services after initial setup
First, set up the project folder:
`bash init-repo.sh`
Then, clear every docker container and volumes related to the project that may be running currently.
`bash reset-containers.sh`
Then, clear the databases, generate users and rooms, erase the `data` folder and run all the uncommented tests.
`bash reset-databases.sh`

## Accessing the services
Synapse: http://localhost:8008
Locust: http://localhost:8089
Jaeger: http://localhost:16686
Prometheus: http://localhost:9091
Grafana: http://localhost:3000, admin/admin

## General architecture from Docker Compose
Databases
    PostgreSQL
    Redis
Simulation stack
    Synapse main process
    Generic workers for Synapse
    Nginx
    Matrix Locust
Observability stack
    OpenTelemetry Collector
    Jaeger
    Prometheus
    Grafana
