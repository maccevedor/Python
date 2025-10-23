import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.main import app
from app.database import Base, get_db
from app.models import TaskStatus

# Create test database
SQLALCHEMY_DATABASE_URL = "sqlite:///./test.db"
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base.metadata.create_all(bind=engine)


def override_get_db():
    try:
        db = TestingSessionLocal()
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db

client = TestClient(app)


@pytest.fixture(autouse=True)
def cleanup_database():
    """Clean up database before each test"""
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield


def test_read_root():
    """Test root endpoint"""
    response = client.get("/")
    assert response.status_code == 200
    assert "message" in response.json()
    assert response.json()["version"] == "1.0.0"


def test_health_check():
    """Test health check endpoint"""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json()["status"] == "healthy"


def test_create_task():
    """Test creating a new task"""
    task_data = {
        "title": "Test Task",
        "description": "This is a test task"
    }
    response = client.post("/tasks", json=task_data)
    assert response.status_code == 201
    data = response.json()
    assert data["title"] == task_data["title"]
    assert data["description"] == task_data["description"]
    assert data["status"] == TaskStatus.PENDING.value
    assert "id" in data


def test_create_task_without_description():
    """Test creating a task without description"""
    task_data = {
        "title": "Test Task"
    }
    response = client.post("/tasks", json=task_data)
    assert response.status_code == 201
    data = response.json()
    assert data["title"] == task_data["title"]
    assert data["description"] is None


def test_create_task_invalid_data():
    """Test creating a task with invalid data"""
    task_data = {
        "title": ""  # Empty title should fail validation
    }
    response = client.post("/tasks", json=task_data)
    assert response.status_code == 422


def test_list_tasks():
    """Test listing tasks"""
    # Create some tasks
    for i in range(3):
        client.post("/tasks", json={"title": f"Task {i}"})
    
    response = client.get("/tasks")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 3


def test_list_tasks_with_pagination():
    """Test listing tasks with pagination"""
    # Create 5 tasks
    for i in range(5):
        client.post("/tasks", json={"title": f"Task {i}"})
    
    response = client.get("/tasks?skip=2&limit=2")
    assert response.status_code == 200
    data = response.json()
    assert len(data) == 2


def test_get_task():
    """Test getting a specific task"""
    # Create a task
    create_response = client.post("/tasks", json={"title": "Test Task"})
    task_id = create_response.json()["id"]
    
    # Get the task
    response = client.get(f"/tasks/{task_id}")
    assert response.status_code == 200
    data = response.json()
    assert data["id"] == task_id
    assert data["title"] == "Test Task"


def test_get_nonexistent_task():
    """Test getting a task that doesn't exist"""
    response = client.get("/tasks/999")
    assert response.status_code == 404


def test_update_task():
    """Test updating a task"""
    # Create a task
    create_response = client.post("/tasks", json={"title": "Original Title"})
    task_id = create_response.json()["id"]
    
    # Update the task
    update_data = {
        "title": "Updated Title",
        "status": TaskStatus.COMPLETED.value
    }
    response = client.put(f"/tasks/{task_id}", json=update_data)
    assert response.status_code == 200
    data = response.json()
    assert data["title"] == "Updated Title"
    assert data["status"] == TaskStatus.COMPLETED.value


def test_update_nonexistent_task():
    """Test updating a task that doesn't exist"""
    update_data = {"title": "Updated Title"}
    response = client.put("/tasks/999", json=update_data)
    assert response.status_code == 404


def test_delete_task():
    """Test deleting a task"""
    # Create a task
    create_response = client.post("/tasks", json={"title": "Task to Delete"})
    task_id = create_response.json()["id"]
    
    # Delete the task
    response = client.delete(f"/tasks/{task_id}")
    assert response.status_code == 200
    assert "deleted successfully" in response.json()["message"]
    
    # Verify task is deleted
    get_response = client.get(f"/tasks/{task_id}")
    assert get_response.status_code == 404


def test_delete_nonexistent_task():
    """Test deleting a task that doesn't exist"""
    response = client.delete("/tasks/999")
    assert response.status_code == 404
