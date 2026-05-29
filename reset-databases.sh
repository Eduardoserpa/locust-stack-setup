# Resetting databases
docker compose -p matrix-stack exec postgres psql -U synapse -d synapse -c "DELETE FROM profiles CASCADE;"
docker compose -p matrix-stack exec postgres psql -U synapse -d synapse -c "DELETE FROM users CASCADE;"
docker compose -p matrix-stack exec postgres psql -U synapse -d synapse -c "DELETE FROM rooms CASCADE;"
docker compose -p matrix-stack exec postgres psql -U synapse -d synapse -c "DELETE FROM user_threepids CASCADE;"
docker compose -p matrix-stack exec postgres psql -U synapse -d synapse -c "DELETE FROM access_tokens CASCADE;"
docker compose -p matrix-stack exec postgres psql -U synapse -d synapse -c "DELETE FROM refresh_tokens CASCADE;"
docker compose -p matrix-stack exec postgres psql -U synapse -d synapse -c "DELETE FROM deleted_pushers CASCADE;"
docker compose -p matrix-stack exec postgres psql -U synapse -d synapse -c "DELETE FROM pushers CASCADE;"

docker compose -p matrix-stack exec -T locust poetry run python generate_users.py 100
docker compose -p matrix-stack exec -T locust poetry run python generate_rooms.py

# Load testing
  # --host=http://synapse:8008 #previous host for direct synapse access, now using nginx as reverse proxy
echo "Test 1 - User Registration"
docker compose -p matrix-stack exec locust poetry run python -m locust \
  -f matrix_locust/client_server/register.py \
  --host=http://nginx:80 \
  --headless --users=100 --spawn-rate=1 --run-time=15s

echo "Test 2 - Room Creation"
docker compose -p matrix-stack exec locust poetry run python -m locust \
  -f matrix_locust/client_server/create_room.py \
  --host=http://nginx:80 \
  --headless --users=100 --spawn-rate=1 --run-time=30s

echo "Test 3 - Join Rooms"
docker compose -p matrix-stack exec locust poetry run python -m locust \
  -f matrix_locust/client_server/join.py \
  --host=http://nginx:80 \
  --headless --users=100 --spawn-rate=1 --run-time=30s

echo "Test 4 - Chat Activity"
docker compose -p matrix-stack exec locust poetry run python -m locust \
  -f locust-run-users.py \
  --host=http://nginx:80 \
  --headless --users=100 --spawn-rate=1 --run-time=120s
