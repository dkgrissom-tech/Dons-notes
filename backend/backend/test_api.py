import requests
import json

BASE_URL = "http://localhost:8000/v1"

def test_signup():
    url = f"{BASE_URL}/auth/signup"
    data = {
        "email": "test@example.com",
        "password": "testpassword",
        "name": "Test User"
    }
    response = requests.post(url, json=data)
    print(f"Signup Response: {response.status_code}")
    print(response.json())
    return response.json()

def test_login():
    url = f"{BASE_URL}/auth/login"
    data = {
        "username": "test@example.com",
        "password": "testpassword"
    }
    response = requests.post(url, data=data)
    print(f"Login Response: {response.status_code}")
    print(response.json())
    return response.json().get("access_token")

def test_upload(token):
    url = f"{BASE_URL}/meetings/upload"
    headers = {"Authorization": f"Bearer {token}"}
    files = {'file': ('test.m4a', b'fake audio data', 'audio/mp4')}
    data = {'attendees': json.dumps([{'email': 'attendee@example.com', 'name': 'Attendee'}])}
    response = requests.post(url, headers=headers, files=files, data=data)
    print(f"Upload Response: {response.status_code}")
    print(response.json())
    return response.json().get('id')

def test_get_contacts(token):
    url = f"{BASE_URL}/contacts"
    headers = {"Authorization": f"Bearer {token}"}
    response = requests.get(url, headers=headers)
    print(f"Get Contacts Response: {response.status_code}")
    print(response.json())

def test_create_contact(token):
    url = f"{BASE_URL}/contacts"
    headers = {"Authorization": f"Bearer {token}"}
    data = {"email": "contact@example.com", "name": "New Contact"}
    response = requests.post(url, headers=headers, json=data)
    print(f"Create Contact Response: {response.status_code}")
    print(response.json())

def test_attendee_sign_in(meeting_id):
    url = f"{BASE_URL}/meetings/{meeting_id}/attendees/sign-in"
    data = {"email": "new_attendee@example.com", "name": "New Attendee"}
    response = requests.post(url, json=data)
    print(f"Attendee Sign-in Response: {response.status_code}")
    print(response.json())

if __name__ == "__main__":
    try:
        test_signup()
        token = test_login()
        if token:
            meeting_id = test_upload(token)
            test_get_contacts(token)
            test_create_contact(token)
            test_get_contacts(token)
            if meeting_id:
                test_attendee_sign_in(meeting_id)
    except Exception as e:
        print(f"Error: {e}")
