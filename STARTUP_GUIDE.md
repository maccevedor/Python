# 🚀 Startup Guide

## Quick Start (Automated)

### Option 1: One Command Startup (Recommended)

```bash
chmod +x start.sh
./start.sh
```

This script will:
1. ✅ Start all Docker containers
2. ✅ Wait for services to be healthy
3. ✅ Deploy Lambda function automatically
4. ✅ Verify everything is working

### Option 2: Manual Steps

```bash
# 1. Start containers
docker-compose up -d

# 2. Wait for services (30 seconds)
sleep 30

# 3. Deploy Lambda
./setup_lambda_fixed.sh
```

---

## What Gets Started

| Service | Port | URL |
|---------|------|-----|
| **FastAPI** | 8000 | http://localhost:8000 |
| **Admin Dashboard** | 8000 | http://localhost:8000/admin/dashboard |
| **PostgreSQL** | 5432 | localhost:5432 |
| **LocalStack** | 4566 | http://localhost:4566 |

---

## After Startup

### 1. Open Admin Dashboard

```
http://localhost:8000/admin/dashboard
```

You'll see:
- 📊 Database metrics
- 📬 SQS queue status
- ⚡ Lambda function status
- 📋 Recent tasks

### 2. Test the System

Create a task:
```bash
curl -X POST http://localhost:8000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"My First Task","description":"Testing the system"}'
```

Wait 10-15 seconds, then check the dashboard - the task should change from "pending" to "completed"!

### 3. View API Documentation

```
http://localhost:8000/docs
```

---

## Troubleshooting

### Lambda Not Working?

If tasks stay in "pending" status:

```bash
# Check if Lambda exists
docker-compose exec localstack awslocal lambda list-functions

# If empty, redeploy Lambda
./setup_lambda_fixed.sh
```

### Services Not Starting?

```bash
# Check container status
docker-compose ps

# View logs
docker-compose logs api
docker-compose logs localstack
docker-compose logs db

# Restart everything
docker-compose down
./start.sh
```

### Database Connection Issues?

```bash
# Check database is ready
docker-compose exec db pg_isready -U postgres

# Connect to database
docker-compose exec db psql -U postgres -d interview_db

# View tasks
SELECT * FROM tasks;
```

---

## Daily Workflow

### Starting the System

```bash
./start.sh
```

### Stopping the System

```bash
docker-compose down
```

### Restarting After Changes

```bash
# If you changed API code
docker-compose restart api

# If you changed Lambda code
./setup_lambda_fixed.sh

# If you changed docker-compose.yml
docker-compose down
./start.sh
```

---

## File Structure

```
.
├── start.sh                    # ⭐ Main startup script
├── setup_lambda_fixed.sh       # Lambda deployment script
├── docker-compose.yml          # Docker services configuration
├── app/
│   ├── main.py                # FastAPI application
│   └── ...
├── lambda/
│   ├── lambda_function_pg8000.py  # Lambda handler (pg8000 version)
│   └── requirements.txt       # Lambda dependencies
└── localstack/
    └── init-aws.sh            # LocalStack initialization
```

---

## Environment Variables

Default values (can be changed in docker-compose.yml):

```bash
DATABASE_URL=postgresql://postgres:postgres@db:5432/interview_db
AWS_REGION=us-east-1
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
SQS_QUEUE_URL=http://localstack:4566/000000000000/interview-queue
```

---

## Complete Flow

```
1. User creates task via API
   ↓
2. API saves to PostgreSQL (status: "pending")
   ↓
3. API sends message to SQS
   ↓
4. Lambda polls SQS (every few seconds)
   ↓
5. Lambda receives message
   ↓
6. Lambda updates task (status: "processing")
   ↓
7. Lambda executes business logic
   ↓
8. Lambda updates task (status: "completed")
   ↓
9. Lambda deletes message from SQS
```

---

## Quick Commands

```bash
# Start everything
./start.sh

# Stop everything
docker-compose down

# View logs
docker-compose logs -f api

# Check Lambda
docker-compose exec localstack awslocal lambda list-functions

# Check SQS
docker-compose exec localstack awslocal sqs get-queue-attributes \
  --queue-url http://localhost:4566/000000000000/interview-queue \
  --attribute-names All

# Check database
docker-compose exec db psql -U postgres -d interview_db -c "SELECT * FROM tasks;"

# Restart API
docker-compose restart api

# Redeploy Lambda
./setup_lambda_fixed.sh

# Create test task
curl -X POST http://localhost:8000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","description":"Testing"}'
```

---

## 🎉 You're Ready!

Run `./start.sh` and open http://localhost:8000/admin/dashboard

Everything should work automatically! 🚀
