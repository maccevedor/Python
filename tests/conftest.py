import pytest
import os

# Set test environment variables
os.environ["DATABASE_URL"] = "sqlite:///./test.db"
os.environ["AWS_REGION"] = "us-east-1"
os.environ["AWS_ACCESS_KEY_ID"] = "test"
os.environ["AWS_SECRET_ACCESS_KEY"] = "test"
os.environ["SQS_QUEUE_URL"] = "http://localhost:4566/000000000000/test-queue"
os.environ["ENVIRONMENT"] = "test"
