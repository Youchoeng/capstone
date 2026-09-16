import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

def test_e2e():
    print("🚀 Starting E2E Tests...")
    
    # 1. User Registration & Login
    import time
    ts = str(int(time.time()))[-6:]
    email = f"t{ts}@ex.com"
    password = "password123"
    name = f"User{ts}"
    
    res = client.post("/users/register", json={"user_id": email, "password": password, "nickname": name, "age": 20, "health_condition": 1})
    assert res.status_code == 201, f"User creation failed: {res.text}"
    print("User created successfully.")

    res = client.post("/users/login", data={"username": email, "password": password})
    assert res.status_code == 200, f"Login failed: {res.text}"
    token_data = res.json()
    token = token_data["access_token"]
    headers = {"Authorization": f"Bearer {token}"}
    print("JWT Token acquired successfully.")

    # 2. Image Upload
    with open("dummy_image.jpg", "wb") as f:
        f.write(b"dummy content")
    
    with open("dummy_image.jpg", "rb") as f:
        res = client.post("/posts/upload", headers=headers, files={"file": ("dummy_image.jpg", f, "image/jpeg")})
    assert res.status_code == 201, f"Upload failed: {res.text}"
    upload_data = res.json()
    file_url = upload_data.get("url")
    assert file_url is not None, "file_url is missing"
    print(f"Image uploaded successfully. URL: {file_url}")

    # 3. Create Group and Post
    res = client.post("/groups/", headers=headers, json={"name": f"TestGroup_{ts}", "description": "Test", "image_url": ""})
    assert res.status_code == 201, f"Group creation failed: {res.text}"
    group_id = res.json()["group_id"]
    
    res = client.post(f"/groups/{group_id}/posts", headers=headers, json={"title": "Test Post", "content": "Hello World", "is_anonymous": False, "attachment_url": file_url})
    assert res.status_code == 201, f"Group Post creation failed: {res.text}"
    post_id = res.json()["post_id"]
    print(f"Group Post created successfully. ID: {post_id}")
    
    # 4. Like Post (using generic post endpoints)
    res = client.post(f"/posts/{post_id}/like", headers=headers)
    assert res.status_code == 201, f"Like failed: {res.text}"
    like_data = res.json()
    assert like_data.get("likes_count") == 1, f"Like count should be 1, got {like_data}"
    
    res = client.post(f"/posts/{post_id}/like", headers=headers)
    assert res.status_code == 400, "Like should have failed as duplicate"
    print("Post liked and duplicate prevented.")
    
    # 5. Report Post
    res = client.post(f"/posts/{post_id}/report", headers=headers, json={"reason": "spam"})
    assert res.status_code == 201, f"Report failed: {res.text}"
    print("Report submitted successfully.")

    # 6. Delete Post
    res = client.delete(f"/posts/{post_id}", headers=headers)
    assert res.status_code == 200, f"Delete failed: {res.text}"
    print("Post deleted successfully.")
    
    # 7. Delete Group (so that user deletion doesn't fail due to foreign key)
    res = client.delete(f"/groups/{group_id}", headers=headers)
    assert res.status_code == 200, f"Group delete failed: {res.text}"
    print("Group deleted successfully.")
    
    # 8. User Delete
    res = client.delete("/users/me", headers=headers)
    assert res.status_code == 200, f"User delete failed: {res.text}"
    print("User deleted successfully.")
    
    res = client.get("/users/me", headers=headers)
    assert res.status_code in [401, 404], f"User should be unauthorized or not found after delete, got {res.status_code}"
    print("Unauthorized access after user deletion confirmed.")
    
    print("\n✅ All E2E Tests Passed Successfully!")

if __name__ == "__main__":
    test_e2e()
