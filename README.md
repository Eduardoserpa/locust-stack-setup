# locust-stack-setup
## Initial setup
`bash init-repo.sh`
`bash init-services.sh`

## Starting or restarting services after initial setup
First, clear every docker container and volumes that currently exist.
`bash reset-containers.sh`
Then, clear the databases, generate users and rooms, erase the `data` folder and run all the uncommented tests.
`bash reset-databases.sh`
