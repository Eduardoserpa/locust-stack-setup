#!/bin/env python3
import time
import random

import csv
import json
import logging
import resource

from locust import task, constant
from locust import events
from locust.runners import MasterRunner, WorkerRunner

import gevent
from matrix_locust.users.matrixuser import MatrixUser
from nio.responses import RoomCreateError, LoginError

# Preflight ####################################################################

def username_to_userid(username, domain=None):
    # Converts username to user_id. Verify if this logic is correct based on how user_ids are represented in the rooms.json file and how they are stored in the matrix client after login.
    user_id = username
    if not user_id.startswith("@"):
        user_id = "@" + username
    if domain is not None and not ":" in user_id:
        user_id += ":" + domain
    return user_id

@events.init.add_listener
def on_locust_init(environment, **_kwargs):
    # Increase resource limits to prevent OS running out of descriptors
    try:
        resource.setrlimit(resource.RLIMIT_NOFILE, (999999, 999999))
    except ValueError as e:
        logging.warning(f"Failed to increase the resource limit: {e}")

    # Multi-worker
    if isinstance(environment.runner, WorkerRunner):
        print(f"Registered 'load_users' handler on {environment.runner.client_id}")
        environment.runner.register_message("load_users", MatrixRoomCreatorUser.load_users)
    # Single-worker
    elif not isinstance(environment.runner, WorkerRunner) and not isinstance(environment.runner, MasterRunner):
        # Open our list of users
        MatrixRoomCreatorUser.worker_users = csv.DictReader(open("users.csv"))

@events.test_start.add_listener
def on_test_start(environment, **_kwargs):
    # Converts the list of users per room into a list of rooms per user. Verify if this logic is correct based on how user_ids are represented in the rooms.json file and how they are stored in the matrix client after login.
    if not isinstance(environment.runner, MasterRunner):
        user_reader = csv.DictReader(open("users.csv", "r", encoding="utf-8"))

        # Load our list of rooms to be created
        logging.info("Loading rooms list")
        rooms = {}
        with open("rooms.json", "r", encoding="utf-8") as rooms_jsonfile:
            rooms = json.load(rooms_jsonfile)
        logging.info("Success loading rooms list")

        # Now we need to sort of invert the list
        # We need a list of the rooms to be created by each user,
        # with the list of other users who should be invited to each
        MatrixRoomCreatorUser.worker_rooms_for_users = {}
        for room_name, room_users in rooms.items():
            first_user = username_to_userid(room_users[0], domain="matrix.local")
            user_rooms = MatrixRoomCreatorUser.worker_rooms_for_users.get(first_user, [])
            room_info = {
                "name": room_name,
                "users": room_users[1:]
            }
            user_rooms.append(room_info)
            MatrixRoomCreatorUser.worker_rooms_for_users[first_user] = user_rooms

        # Debug: print the keys of worker_rooms_for_users
        all_keys = list(MatrixRoomCreatorUser.worker_rooms_for_users.keys())
        logging.info("Built worker_rooms_for_users with %d users, first 5 keys: %s", len(all_keys), all_keys[:5])

###############################################################################


class MatrixRoomCreatorUser(MatrixUser):
    wait_time = constant(0)
    # wait_time = constant(2)

    worker_id = None
    worker_users = []
    worker_rooms_for_users = {}

    @staticmethod
    def load_users(environment, msg, **_kwargs):
        MatrixRoomCreatorUser.worker_users = iter(msg.data)
        MatrixRoomCreatorUser.worker_id = environment.runner.client_id
        logging.info("Worker [%s]: Received %s users", environment.runner.client_id, len(msg.data))

    @task
    def create_rooms_for_user(self):
        import time as time_module
        task_start = time_module.time()
        
        # ============ LOAD USER FROM CSV ============
        self.reset_client()

        try:
            user = next(MatrixRoomCreatorUser.worker_users)
        except StopIteration:
            gevent.sleep(999999)
            return

        self.set_user(user["username"])
        self.matrix_client.password = user["password"]
        self.matrix_client.matrix_domain = "matrix.local"

        logging.info("=" * 80)
        logging.info("USER LOAD - CSV Data")
        logging.info("  username (local):     [%s]", self.matrix_client.user)
        logging.info("  password:             [%s...]", self.matrix_client.password[:8])
        logging.info("  matrix_domain:        [%s]", self.matrix_client.matrix_domain)
        logging.info("=" * 80)

        if self.matrix_client.user is None or self.matrix_client.password is None:
            logging.error("FAILED - CSV loading failed - username/password empty")
            return

        # ============ LOGIN ATTEMPT ============
        delay = random.uniform(0.1, 0.5)
        logging.info("DELAY - Sleeping %.3f seconds before login", delay)
        time.sleep(delay)
        
        logging.info("LOGIN - Attempting login...")
        response = self.matrix_client.login(self.matrix_client.password, device_name="room-creator")

        logging.info("LOGIN RESPONSE - Type: %s", type(response).__name__)
        
        if isinstance(response, LoginError):
            logging.error("=" * 80)
            logging.error("LOGIN FAILED")
            logging.error("  username:             [%s]", self.matrix_client.user)
            logging.error("  status:               [%s]", response.status_code)
            logging.error("  message:              [%s]", response.message)
            logging.error("  retry_after_ms:       [%s]", getattr(response, 'retry_after_ms', 'N/A'))
            logging.error("=" * 80)
            return

        # ============ VALIDATE user_id AFTER LOGIN ============
        logging.info("LOGIN SUCCESS")
        logging.info("  matrix_client.user_id (FULL ID):  [%s]", self.matrix_client.user_id)
        logging.info("  matrix_client.user (LOCAL):       [%s]", self.matrix_client.user)
        logging.info("  matrix_client.access_token:       [%s...]", 
                    self.matrix_client.access_token[:20] if self.matrix_client.access_token else "None")
        logging.info("  matrix_client.device_id:          [%s]", self.matrix_client.device_id)
        
        # CRITICAL CHECK: user_id must exist and be in proper format
        if self.matrix_client.user_id is None:
            logging.error("CRITICAL - user_id is None after login! Cannot proceed with room creation.")
            return
        
        if ":" not in self.matrix_client.user_id:
            logging.error("CRITICAL - user_id missing domain! Format: [%s]", self.matrix_client.user_id)
            return

        # ============ ROOM LOOKUP ============
        user_key_local = self.matrix_client.user
        user_key_full = self.matrix_client.user_id
        
        # Try both formats for room lookup
        my_rooms_info = MatrixRoomCreatorUser.worker_rooms_for_users.get(user_key_full, [])
        if not my_rooms_info:
            my_rooms_info = MatrixRoomCreatorUser.worker_rooms_for_users.get(user_key_local, [])
        
        logging.info("=" * 80)
        logging.info("ROOM LOOKUP")
        logging.info("  user_key_local:       [%s]", user_key_local)
        logging.info("  user_key_full:        [%s]", user_key_full)
        logging.info("  rooms found:          [%d]", len(my_rooms_info))
        if len(my_rooms_info) == 0:
            all_keys = list(MatrixRoomCreatorUser.worker_rooms_for_users.keys())[:5]
            logging.warning("  sample keys in dict:  %s", all_keys)
        logging.info("=" * 80)

        if len(my_rooms_info) == 0:
            logging.info("No rooms assigned to user [%s], skipping room creation", user_key_full)
            return

        # ============ ROOM CREATION ============
        for idx, room_info in enumerate(my_rooms_info):
            room_name = room_info["name"]
            usernames = room_info["users"]
            user_ids = [username_to_userid(u, domain="matrix.local") for u in usernames]
            
            logging.info("=" * 80)
            logging.info("ROOM CREATION [%d/%d]", idx + 1, len(my_rooms_info))
            logging.info("  creator_user_id:      [%s]", self.matrix_client.user_id)
            logging.info("  room_name:            [%s]", room_name)
            logging.info("  invited_users:        [%s]", user_ids)
            logging.info("=" * 80)

            retries = 3
            while retries > 0:
                logging.info("ROOM CREATE ATTEMPT - [%d/3]", 4 - retries)
                
                try:
                    response = self.matrix_client.room_create(
                        alias=None, name=room_name, invite=user_ids, federate=True
                    )
                    
                    logging.info("ROOM CREATE RESPONSE - Type: %s", type(response).__name__)
                    
                    if isinstance(response, RoomCreateError):
                        logging.error("  ERROR - Code: [%s], Message: [%s]", 
                                    response.status_code, response.message)
                        retries -= 1
                    else:
                        logging.info("  SUCCESS - room_id: [%s]", response.room_id)
                        break
                        
                except Exception as e:
                    logging.exception("  EXCEPTION - %s", type(e).__name__)
                    retries -= 1

            if retries == 0:
                logging.error("Room creation failed after 3 retries - [%s]", room_name)

        elapsed = time_module.time() - task_start
        logging.info("TASK COMPLETE - elapsed time: %.2f seconds", elapsed)
