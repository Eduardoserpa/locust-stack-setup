# # Bringing down Docker
# echo "Bringing down Docker Compose services from the current folder"
# docker compose down --rmi all --volumes --remove-orphans
echo "Stopping containers"
docker stop $(docker ps -aq)
echo "Removing containers"
docker rm -f $(docker ps -aq)
echo "Removing images"
docker rmi -f $(docker images -aq)
echo "Removing volumes"
docker volume rm -f $(docker volume ls -q)
echo "Removing networks"
docker network prune -f
echo "Remove all unused containers, networks, images, and volumes"
docker system prune -a --volumes -f

## Cleaning databases

## Setting up
./setup-matrix-stack.sh init
./setup-matrix-stack.sh start
docker compose exec postgres psql -U synapse -d synapse -c "DELETE FROM profiles CASCADE;"
docker compose exec postgres psql -U synapse -d synapse -c "DELETE FROM users CASCADE;"
docker compose exec postgres psql -U synapse -d synapse -c "DELETE FROM rooms CASCADE;"
docker compose exec postgres psql -U synapse -d synapse -c "DELETE FROM user_threepids CASCADE;"
docker compose exec postgres psql -U synapse -d synapse -c "DELETE FROM access_tokens CASCADE;"
docker compose exec postgres psql -U synapse -d synapse -c "DELETE FROM refresh_tokens CASCADE;"
docker compose exec postgres psql -U synapse -d synapse -c "DELETE FROM deleted_pushers CASCADE;"
docker compose exec postgres psql -U synapse -d synapse -c "DELETE FROM pushers CASCADE;"

docker compose exec -T locust poetry run python generate_users.py 100
docker compose exec -T locust poetry run python generate_rooms.py

## Load testing
echo "Test 1 - User Registration"
docker compose exec locust poetry run python -m locust \
  -f matrix_locust/client_server/register.py \
  --host=http://synapse:8008 \
  --headless --users=100 --spawn-rate=2 --run-time=60s

# echo "Test 2 - Room Creation"
# docker compose exec locust poetry run python -m locust \
#   -f matrix_locust/client_server/create_room.py \
#   --host=http://synapse:8008 \
#   --headless --users=100 --spawn-rate=0.5 --run-time=240s

# echo "Test 3 - Join Rooms"
# docker compose exec locust poetry run python -m locust \
#   -f matrix_locust/client_server/join.py \
#   --host=http://synapse:8008 \
#   --headless --users=20 --spawn-rate=2 --run-time=30s

# echo "Test 4 - Chat Activity"
# docker compose exec locust poetry run python -m locust \
#   -f locust-run-users.py \
#   --host=http://synapse:8008 \
#   --headless --users=10 --spawn-rate=1 --run-time=60s
