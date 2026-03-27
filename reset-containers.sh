# # Bringing down Docker
# echo "Bringing down Docker Compose services from the current folder"
# docker compose -p matrix-stack down --rmi all --volumes --remove-orphans

echo "Stopping containers"
docker compose -p matrix-stack stop $(docker compose -p matrix-stack ps -aq)
echo "Removing containers"
docker compose -p matrix-stack rm -f $(docker compose -p matrix-stack ps -aq)
echo "Removing images"
docker compose -p matrix-stack rmi -f $(docker compose -p matrix-stack images -aq)
echo "Removing volumes"
docker compose -p matrix-stack volume rm -f $(docker compose -p matrix-stack volume ls -q)
echo "Removing networks"
docker compose -p matrix-stack network prune -f
echo "Remove all unused containers, networks, images, and volumes"
docker compose -p matrix-stack system prune -a --volumes -f

sudo systemctl restart docker

# # Cleaning files and databases
sudo rm -r ./data/
mkdir data
sudo chmod -R 755 ./data

# # Setting up
./setup-matrix-stack.sh init
./setup-matrix-stack.sh start
