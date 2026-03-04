#!/usr/bin/env python
"""
Locust task definitions for testing Matrix Synapse
Extends the matrix-locust library to test Synapse server
"""

import os
import sys
from locust import HttpUser, task, between

# This is a template for custom Locust tasks
# Users can extend this to define custom behavior patterns

class MatrixUser(HttpUser):
    """Basic Matrix user for load testing Synapse"""
    
    wait_time = between(1, 5)  # Wait 1-5 seconds between requests
    
    def on_start(self):
        """Called when a simulated user starts"""
        # You can implement user registration and login here
        pass
    
    @task(1)
    def get_sync(self):
        """Perform a sync request to retrieve room state"""
        self.client.get("/_matrix/client/r0/sync")
    
    @task(2)
    def get_user_info(self):
        """Get information about the current user"""
        self.client.get("/_matrix/client/r0/account/whoami")
    
    @task(1)
    def get_room_state(self):
        """Get state of a room (example roomID)"""
        self.client.get("/_matrix/client/r0/rooms/!example:matrix.local/state")


class RegisteredMatrixUser(HttpUser):
    """Matrix user that performs user registration and login"""
    
    wait_time = between(2, 10)
    
    def on_start(self):
        """Register and login when user starts"""
        import string
        import random
        
        # Generate random username
        username = ''.join(random.choices(string.ascii_lowercase + string.digits, k=10))
        password = "test_password_123"
        
        # Register
        register_data = {
            "auth": {"type": "m.login.dummy"},
            "username": username,
            "password": password
        }
        
        self.client.post(
            "/_matrix/client/r0/register",
            json=register_data
        )
        
        # Login
        login_data = {
            "type": "m.login.password",
            "user": username,
            "password": password
        }
        
        resp = self.client.post(
            "/_matrix/client/r0/login",
            json=login_data
        )
        
        if resp.status_code == 200:
            self.access_token = resp.json().get("access_token")
            self.user_id = resp.json().get("user_id")
    
    @task(3)
    def sync(self):
        """Sync with the server"""
        self.client.get(
            "/_matrix/client/r0/sync",
            headers={"Authorization": f"Bearer {self.access_token}"}
        )
    
    @task(1)
    def get_joined_rooms(self):
        """Get list of joined rooms"""
        self.client.get(
            "/_matrix/client/r0/joined_rooms",
            headers={"Authorization": f"Bearer {self.access_token}"}
        )
