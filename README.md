# Interview Project - FastAPI Backend with AWS Services

A comprehensive interview project demonstrating a production-ready microservices architecture using Python, FastAPI, AWS SQS, Lambda, PostgreSQL, and Docker.

## 🏗️ Architecture Overview

```
┌─────────────┐      ┌──────────────┐      ┌─────────────┐
│   FastAPI   │─────▶│   AWS SQS    │─────▶│AWS Lambda   │
│   Backend   │      │    Queue     │      │  Function   │
└──────┬──────┘      └──────────────┘      └──────┬──────┘
       │                                            │
       │            ┌──────────────┐               │
       └───────────▶│  PostgreSQL  │◀──────────────┘
                    │   Database   │
                    └──────────────┘
```

### Components

- **FastAPI Backend**: RESTful API for task management
- **PostgreSQL**: Relational database for persistent storage
- **AWS SQS**: Message queue for asynchronous task processing
- **AWS Lambda**: Serverless function for processing tasks
- **Docker**: Containerization for easy deployment
- **LocalStack**: Local AWS services emulation for development

## 🚀 Features

- ✅ RESTful API with FastAPI
- ✅ PostgreSQL database with SQLAlchemy ORM
- ✅ Asynchronous task processing with SQS
- ✅ AWS Lambda function for message processing
- ✅ Docker Compose for local development
- ✅ Pydantic models for data validation
- ✅ Comprehensive test suite
- ✅ Health check endpoints
- ✅ Environment-based configuration
- ✅ Database migrations with Alembic

## 📋 Prerequisites

- Docker and Docker Compose
- Python 3.11+ (for local development)
- AWS Account (for production deployment)
- Git

## 🛠️ Installation & Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd python
```

### 2. Environment Configuration

Create a `.env` file from the example:

```bash
cp .env.example .env
```

Edit `.env` with your configuration:

```env
DATABASE_URL=postgresql://postgres:postgres@db:5432/interview_db
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
SQS_QUEUE_URL=https://sqs.us-east-1.amazonaws.com/123456789/interview-queue
ENVIRONMENT=development
```

### 3. Start the Application

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Check service status
docker-compose ps
```

### 4. Initialize LocalStack (Development)

```bash
# Make the init script executable
chmod +x localstack/init-aws.sh

# The script runs automatically when LocalStack starts
# Or run manually:
docker-compose exec localstack /etc/localstack/init/ready.d/init-aws.sh
```

### 5. Access the Application

- **API Documentation**: http://localhost:8000/docs
- **Alternative API Docs**: http://localhost:8000/redoc
- **Health Check**: http://localhost:8000/health
- **PostgreSQL**: localhost:5432
- **LocalStack**: http://localhost:4566

## 📚 API Endpoints

### Tasks

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Root endpoint with API info |
| GET | `/health` | Health check |
| POST | `/tasks` | Create a new task |
| GET | `/tasks` | List all tasks (with pagination) |
| GET | `/tasks/{task_id}` | Get a specific task |
| PUT | `/tasks/{task_id}` | Update a task |
| DELETE | `/tasks/{task_id}` | Delete a task |
| POST | `/tasks/{task_id}/process` | Manually trigger task processing |

### Example Requests

#### Create a Task

```bash
curl -X POST "http://localhost:8000/tasks" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Process user data",
    "description": "Extract and transform user information"
  }'
```

#### List Tasks

```bash
curl "http://localhost:8000/tasks?skip=0&limit=10"
```

#### Get Task by ID

```bash
curl "http://localhost:8000/tasks/1"
```

#### Update Task

```bash
curl -X PUT "http://localhost:8000/tasks/1" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Updated title",
    "status": "completed"
  }'
```

#### Delete Task

```bash
curl -X DELETE "http://localhost:8000/tasks/1"
```

## 🧪 Testing

### Run Tests

```bash
# Install dependencies
pip install -r requirements.txt

# Run all tests
pytest

# Run with coverage
pytest --cov=app --cov-report=html

# Run specific test file
pytest tests/test_api.py

# Run with verbose output
pytest -v
```

### Test Coverage

The test suite includes:
- Unit tests for API endpoints
- Integration tests with database
- Validation tests for Pydantic models
- Error handling tests

## 🗄️ Database Management

### Migrations with Alembic

```bash
# Initialize Alembic (already done)
alembic init alembic

# Create a new migration
alembic revision --autogenerate -m "description"

# Apply migrations
alembic upgrade head

# Rollback migration
alembic downgrade -1

# View migration history
alembic history
```

### Database Access

```bash
# Connect to PostgreSQL
docker-compose exec db psql -U postgres -d interview_db

# Common SQL commands
\dt              # List tables
\d tasks         # Describe tasks table
SELECT * FROM tasks;
```

## 🔧 Development

### Project Structure

```
.
├── app/
│   ├── __init__.py
│   ├── main.py           # FastAPI application
│   ├── config.py         # Configuration management
│   ├── database.py       # Database connection
│   ├── models.py         # SQLAlchemy models
│   ├── schemas.py        # Pydantic schemas
│   └── sqs_client.py     # AWS SQS client
├── lambda/
│   ├── lambda_function.py # Lambda handler
│   ├── requirements.txt   # Lambda dependencies
│   └── Dockerfile         # Lambda container
├── localstack/
│   └── init-aws.sh       # LocalStack initialization
├── tests/
│   ├── __init__.py
│   ├── conftest.py       # Test configuration
│   └── test_api.py       # API tests
├── docker-compose.yml    # Docker services
├── Dockerfile            # API container
├── requirements.txt      # Python dependencies
├── .env.example          # Environment template
├── .gitignore
├── INTERVIEW_QUESTIONS.md # Interview questions
└── README.md
```

### Local Development Without Docker

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Set environment variables
export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/interview_db"
export AWS_REGION="us-east-1"
# ... other variables

# Run the application
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## 🚢 Production Deployment

### AWS Deployment

#### 1. Deploy Lambda Function

```bash
# Build Lambda Docker image
cd lambda
docker build -t interview-lambda .

# Tag and push to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
docker tag interview-lambda:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/interview-lambda:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/interview-lambda:latest

# Create Lambda function
aws lambda create-function \
  --function-name interview-processor \
  --package-type Image \
  --code ImageUri=<account-id>.dkr.ecr.us-east-1.amazonaws.com/interview-lambda:latest \
  --role arn:aws:iam::<account-id>:role/lambda-execution-role
```

#### 2. Create SQS Queue

```bash
# Create queue
aws sqs create-queue --queue-name interview-queue

# Configure Lambda trigger
aws lambda create-event-source-mapping \
  --function-name interview-processor \
  --event-source-arn arn:aws:sqs:us-east-1:<account-id>:interview-queue \
  --batch-size 10
```

#### 3. Deploy API (ECS/Fargate or EC2)

```bash
# Build and push API image
docker build -t interview-api .
docker tag interview-api:latest <account-id>.dkr.ecr.us-east-1.amazonaws.com/interview-api:latest
docker push <account-id>.dkr.ecr.us-east-1.amazonaws.com/interview-api:latest

# Deploy to ECS (example)
# Create task definition, service, and configure load balancer
```

#### 4. RDS PostgreSQL Setup

```bash
# Create RDS instance
aws rds create-db-instance \
  --db-instance-identifier interview-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --master-username postgres \
  --master-user-password <password> \
  --allocated-storage 20
```

## 🔒 Security Considerations

- ✅ Use AWS Secrets Manager for sensitive credentials
- ✅ Implement JWT authentication for API endpoints
- ✅ Enable HTTPS/TLS in production
- ✅ Use IAM roles instead of access keys
- ✅ Enable VPC for database and Lambda
- ✅ Implement rate limiting
- ✅ Regular security updates
- ✅ Input validation with Pydantic
- ✅ SQL injection prevention with ORM

## 📊 Monitoring & Logging

### CloudWatch Integration

```python
# Add to Lambda function
import logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Add to FastAPI
import logging
logging.basicConfig(level=logging.INFO)
```

### Metrics to Monitor

- API response times
- Database connection pool
- SQS queue depth
- Lambda execution duration
- Error rates
- Task processing success/failure rates

## 🐛 Troubleshooting

### Common Issues

#### 1. Database Connection Failed

```bash
# Check if database is running
docker-compose ps db

# Check database logs
docker-compose logs db

# Restart database
docker-compose restart db
```

#### 2. SQS Connection Issues

```bash
# Check LocalStack logs
docker-compose logs localstack

# Verify queue exists
docker-compose exec localstack awslocal sqs list-queues

# Recreate queue
docker-compose exec localstack awslocal sqs create-queue --queue-name interview-queue
```

#### 3. Lambda Not Processing Messages

- Check Lambda logs in CloudWatch
- Verify SQS trigger is configured
- Check IAM permissions
- Verify database connectivity from Lambda

#### 4. API Container Won't Start

```bash
# Check logs
docker-compose logs api

# Rebuild container
docker-compose build api
docker-compose up -d api
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 Interview Questions

See [INTERVIEW_QUESTIONS.md](INTERVIEW_QUESTIONS.md) for comprehensive interview questions covering:
- Python & FastAPI
- PostgreSQL & SQLAlchemy
- AWS Services (SQS, Lambda)
- Docker & DevOps
- System Design & Architecture
- Practical Coding Tasks
- Debugging Scenarios

## 📄 License

This project is created for interview and educational purposes.

## 🔗 Resources

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [SQLAlchemy Documentation](https://docs.sqlalchemy.org/)
- [AWS SQS Documentation](https://docs.aws.amazon.com/sqs/)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Docker Documentation](https://docs.docker.com/)
- [LocalStack Documentation](https://docs.localstack.cloud/)

## 📧 Contact

For questions or feedback about this project, please open an issue in the repository.

---

**Happy Coding! 🚀**
