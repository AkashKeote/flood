#!/usr/bin/env python3
"""
Test Email Alert System
Quick test to verify email alerts are working
"""
import requests
import json

# Server URL
BASE_URL = "http://127.0.0.1:5000"

def test_server():
    """Test if server is running"""
    try:
        response = requests.get(BASE_URL)
        print(f"✅ Server Status: {response.status_code}")
        print(f"Response: {response.text}")
        return True
    except Exception as e:
        print(f"❌ Server not running: {e}")
        return False

def test_user_registration():
    """Test user registration"""
    user_data = {
        "name": "Test User",
        "email": "test@example.com",  # Change this to your email
        "region": "Andheri East"
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/register_user",
            headers={"Content-Type": "application/json"},
            json=user_data
        )
        
        print(f"📝 Registration Status: {response.status_code}")
        print(f"Response: {response.json()}")
        return response.status_code == 200
    except Exception as e:
        print(f"❌ Registration failed: {e}")
        return False

def test_email_alert():
    """Test sending email alert"""
    alert_data = {
        "email": "test@example.com",  # Change this to your email
        "region": "Andheri East",
        "risk_level": "high"
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/send_alert",
            headers={"Content-Type": "application/json"},
            json=alert_data
        )
        
        print(f"📧 Email Alert Status: {response.status_code}")
        print(f"Response: {response.json()}")
        return response.status_code == 200
    except Exception as e:
        print(f"❌ Email alert failed: {e}")
        return False

if __name__ == "__main__":
    print("🧪 Testing Flood Alert Email System\n")
    
    # Test 1: Server Status
    print("1. Testing Server...")
    if not test_server():
        print("Please start the server first: python api/server.py")
        exit(1)
    
    print("\n" + "="*50 + "\n")
    
    # Test 2: User Registration
    print("2. Testing User Registration...")
    test_user_registration()
    
    print("\n" + "="*50 + "\n")
    
    # Test 3: Email Alert
    print("3. Testing Email Alert...")
    test_email_alert()
    
    print("\n✅ Email system tests completed!")
    print("Check your email inbox for the flood alert message.")
