#!/usr/bin/env python3
"""
PingMailer API Client Example

This script demonstrates how to use the PingMailer API with dual authentication:
1. Application authentication via OAuth2 client credentials
2. User authentication via SMTP credentials in the request
"""

import os
import sys
import json
import requests
from typing import Dict, Optional
from dataclasses import dataclass
import urllib3

# Disable SSL warnings for self-signed certificates (development only)
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


@dataclass
class OAuth2Config:
    """OAuth2 configuration for application authentication"""
    token_url: str
    client_id: str
    client_secret: str


@dataclass
class SMTPConfig:
    """SMTP configuration for user authentication"""
    host: str
    port: int
    username: str
    password: str
    sender: str


@dataclass
class EmailRequest:
    """Email notification request"""
    recipient_email: str
    recipient_name: Optional[str] = None
    app_name: Optional[str] = None
    template: Optional[str] = None
    template_data: Optional[Dict] = None


class PingMailerClient:
    """Client for PingMailer API with dual authentication"""

    def __init__(self, api_url: str, oauth2_config: OAuth2Config, smtp_config: SMTPConfig):
        self.api_url = api_url.rstrip('/')
        self.oauth2_config = oauth2_config
        self.smtp_config = smtp_config
        self._access_token: Optional[str] = None

    def _get_access_token(self) -> str:
        """Get application access token via OAuth2 client credentials flow"""
        print("Requesting application access token...")
        
        response = requests.post(
            self.oauth2_config.token_url,
            data={'grant_type': 'client_credentials'},
            auth=(self.oauth2_config.client_id, self.oauth2_config.client_secret),
            verify=False  # Only for development with self-signed certs
        )
        
        if response.status_code != 200:
            raise Exception(f"Failed to get access token: {response.status_code} - {response.text}")
        
        token_data = response.json()
        self._access_token = token_data['access_token']
        
        print(f"✓ Access token obtained (expires in {token_data.get('expires_in', 'unknown')} seconds)")
        return self._access_token

    def send_notification(self, email_request: EmailRequest) -> bool:
        """
        Send email notification using dual authentication:
        - Bearer token for application authentication
        - SMTP credentials for user authentication
        """
        # Get access token if not already available
        if not self._access_token:
            self._get_access_token()

        print(f"\nSending notification to {email_request.recipient_email}...")

        # Build request payload
        payload = {
            'smtp_host': self.smtp_config.host,
            'smtp_port': self.smtp_config.port,
            'smtp_username': self.smtp_config.username,
            'smtp_password': self.smtp_config.password,
            'smtp_sender': self.smtp_config.sender,
            'recipient_email': email_request.recipient_email,
        }

        if email_request.recipient_name:
            payload['recipient_name'] = email_request.recipient_name
        if email_request.app_name:
            payload['app_name'] = email_request.app_name
        if email_request.template:
            payload['template'] = email_request.template
        if email_request.template_data:
            payload['template_data'] = email_request.template_data

        # Send request with Bearer token
        headers = {
            'Authorization': f'Bearer {self._access_token}',
            'Content-Type': 'application/json'
        }

        response = requests.post(
            f'{self.api_url}/notify',
            json=payload,
            headers=headers,
            verify=False  # Only for development with self-signed certs
        )

        if response.status_code == 200:
            print("✓ Email notification queued successfully")
            return True
        else:
            print(f"✗ Failed to send notification: {response.status_code} - {response.text}")
            return False

    def health_check(self) -> bool:
        """Check API server health"""
        print("\nChecking server health...")
        
        response = requests.get(
            f'{self.api_url}/health',
            verify=False
        )
        
        if response.status_code == 200:
            health_data = response.json()
            print(f"✓ Server is healthy: {json.dumps(health_data, indent=2)}")
            return True
        else:
            print(f"✗ Health check failed: {response.status_code}")
            return False


def main():
    """Example usage of PingMailer API client"""
    
    # Configuration from environment variables or defaults
    oauth2_config = OAuth2Config(
        token_url=os.getenv('OAUTH2_TOKEN_URL', 'https://localhost:8090/oauth2/token'),
        client_id=os.getenv('OAUTH2_CLIENT_ID', 'your-client-id'),
        client_secret=os.getenv('OAUTH2_CLIENT_SECRET', 'your-client-secret')
    )
    
    smtp_config = SMTPConfig(
        host=os.getenv('SMTP_HOST', 'smtp.gmail.com'),
        port=int(os.getenv('SMTP_PORT', '587')),
        username=os.getenv('SMTP_USERNAME', 'user@gmail.com'),
        password=os.getenv('SMTP_PASSWORD', 'user-app-password'),
        sender=os.getenv('SMTP_SENDER', 'user@gmail.com')
    )
    
    api_url = os.getenv('API_URL', 'https://localhost:8080')
    
    print("=== PingMailer API Client Demo ===\n")
    print(f"API Server: {api_url}")
    print(f"OAuth2 Server: {oauth2_config.token_url}")
    print(f"SMTP Server: {smtp_config.host}:{smtp_config.port}")
    print()
    
    # Create client
    client = PingMailerClient(api_url, oauth2_config, smtp_config)
    
    try:
        # Check server health
        if not client.health_check():
            print("\n⚠ Server health check failed, but continuing...")
        
        # Send email notification
        email_request = EmailRequest(
            recipient_email='recipient@example.com',
            recipient_name='Jane Doe',
            app_name='PingMailer Python Demo'
        )
        
        success = client.send_notification(email_request)
        
        if success:
            print("\n=== Demo completed successfully ===")
            return 0
        else:
            print("\n=== Demo failed ===")
            return 1
            
    except Exception as e:
        print(f"\n✗ Error: {e}")
        return 1


if __name__ == '__main__':
    sys.exit(main())
