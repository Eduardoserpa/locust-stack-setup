#!/usr/bin/env python3
"""Debug script to test register with more details"""

import logging
import sys

# Set up detailed logging
logging.basicConfig(
    level=logging.DEBUG,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    stream=sys.stdout
)

from locust import FastHttpUser, task, constant, events
from locust.env import Environment
from matrix_locust.nio.locust_client import LocustClient
import csv

# Set up environment
env = Environment()

class TestMatrixUser(FastHttpUser):
    """Simple test user for registration"""
    host = "http://synapse:8008"
    wait_time = constant(0)
    
    def on_start(self):
        """Initialize on user start"""
        self.matrix_client = LocustClient(self)
        self.username = None
        self.password = None
    
    @task
    def register_test(self):
        """Test registration"""
        if not self.username:
            # Load a user from CSV
            try:
                with open("users.csv") as f:
                    reader = csv.DictReader(f)
                    user_data = next(reader)
                    self.username = user_data["username"]
                    self.password = user_data["password"]
            except StopIteration:
                logging.error("No users in CSV file")
                return
        
        logging.info(f"Attempting to register user: {self.username}")
        
        # Try to register
        try:
            result = self.matrix_client.register(self.username, self.password)
            logging.info(f"Register result: {result}")
        except Exception as e:
            logging.exception(f"Register failed with exception:")

# Spawn user and run
user = TestMatrixUser(env)
user.on_start()
user.register_test()
