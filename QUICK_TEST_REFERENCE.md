# 🚀 Quick Test Reference - Complete Flow

## 📋 Step-by-Step Testing

### 1️⃣ Create a Task

```bash
curl -X POST http://localhost:8000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"My Test Task","description":"Testing the flow"}'
```

**Response:**
```json
{"id": 7, "status": "pending", "title": "My Test Task"}
```

**Code Location:** `app/main.py` lines 39-75

---

### 2️⃣ Check Task Status

```bash
curl http://localhost:8000/tasks/7 | python3 -m json.tool
```

**Code Location:** `app/main.py` lines 77-82

---

### 3️⃣ Check SQS Queue

```bash
docker-compose exec localstack awslocal sqs receive-message \
  --queue-url http://localhost:4566/000000000000/interview-queue
```

**Code Location:** Message sent by `app/sqs_client.py` lines 19-29

---

### 4️⃣ Check Lambda Function

```bash
docker-compose exec localstack awslocal lambda list-functions
```

**Code Location:** Lambda defined in `lambda/lambda_function.py` lines 31-117

---

### 5️⃣ Run Complete Test

```bash
./test_end_to_end.sh
```

This tests the entire flow automatically!

---

## 📍 Code Locations Map

```
┌─────────────────────────────────────────────────────────────┐
│ REQUEST: POST /tasks                                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 📍 app/main.py (lines 39-75)                                │
│                                                              │
│ • Validates input                                           │
│ • Creates task in database (status: "pending")             │
│ • Calls sqs_client.send_message()                          │
│ • Returns response                                          │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 📍 app/sqs_client.py (lines 19-29)                          │
│                                                              │
│ • Converts message to JSON                                  │
│ • Uses boto3 to send to SQS                                │
│ • Returns MessageId                                         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 📍 SQS Queue (LocalStack)                                   │
│                                                              │
│ • Stores message                                            │
│ • Waits for Lambda to poll                                 │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│ 📍 lambda/lambda_function.py (lines 31-117)                 │
│                                                              │
│ • Receives message from SQS                                │
│ • Parses task_id, title, description                       │
│ • Connects to database                                      │
│ • Updates status to "processing"                           │
│ • Calls process_task() (lines 17-28)                       │
│ • Updates status to "completed"                            │
│ • Returns success (SQS deletes message)                    │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎯 Key Files & What They Do

| File | Lines | Purpose |
|------|-------|---------|
| `app/main.py` | 39-75 | API endpoint - creates task, sends to SQS |
| `app/sqs_client.py` | 19-29 | Sends messages to SQS queue |
| `lambda/lambda_function.py` | 31-117 | Processes SQS messages |
| `lambda/lambda_function.py` | 17-28 | Business logic (process_task) |
| `app/models.py` | 8-20 | Database model (Task table) |
| `app/schemas.py` | 8-12 | Input validation (TaskCreate) |

---

## 🧪 Quick Test Commands

```bash
# 1. Create task and get ID
TASK_ID=$(curl -s -X POST http://localhost:8000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Quick Test"}' | grep -o '"id":[0-9]*' | grep -o '[0-9]*')

echo "Created task ID: $TASK_ID"

# 2. Check status
curl http://localhost:8000/tasks/$TASK_ID | python3 -m json.tool

# 3. Check queue
docker-compose exec localstack awslocal sqs get-queue-attributes \
  --queue-url http://localhost:4566/000000000000/interview-queue \
  --attribute-names ApproximateNumberOfMessages

# 4. List all tasks
curl http://localhost:8000/tasks | python3 -m json.tool
```

---

## 📊 What Each Step Does

### Step 1: API Creates Task
**File:** `app/main.py` line 47-54
```python
db_task = Task(
    title=task.title,
    description=task.description,
    status=TaskStatus.PENDING  # ← Starts as "pending"
)
db.add(db_task)
db.commit()
```

### Step 2: API Sends to SQS
**File:** `app/main.py` line 58-63
```python
message = {
    "task_id": db_task.id,
    "title": db_task.title,
    "description": db_task.description
}
sqs_client.send_message(message)  # ← Sends to queue
```

### Step 3: SQS Client Sends
**File:** `app/sqs_client.py` line 22-25
```python
response = self.client.send_message(
    QueueUrl=self.queue_url,
    MessageBody=json.dumps(message_body)  # ← boto3 sends to SQS
)
```

### Step 4: Lambda Receives
**File:** `lambda/lambda_function.py` line 41-47
```python
for record in event['Records']:
    message_body = json.loads(record['body'])
    task_id = message_body.get('task_id')  # ← Gets task ID
    title = message_body.get('title')
```

### Step 5: Lambda Processes
**File:** `lambda/lambda_function.py` line 56-73
```python
# Update to "processing"
UPDATE tasks SET status = 'processing' WHERE id = task_id

# Do the work
result = process_task(task_id, title, description)

# Update to "completed"
UPDATE tasks SET status = 'completed', result = result WHERE id = task_id
```

---

## 🎓 Interview Talking Points

### Architecture
- **Async Processing**: API returns immediately, processing happens in background
- **Decoupling**: API and Lambda are independent
- **Scalability**: Lambda auto-scales based on queue depth
- **Reliability**: Messages persist in SQS if processing fails

### Technologies
- **FastAPI**: Modern Python web framework
- **PostgreSQL**: Relational database
- **AWS SQS**: Message queue service
- **AWS Lambda**: Serverless compute
- **boto3**: AWS SDK for Python
- **Docker**: Containerization

### Flow
1. Client → API (FastAPI)
2. API → Database (PostgreSQL)
3. API → Queue (SQS)
4. Queue → Lambda (Automatic trigger)
5. Lambda → Database (Update status)

---

## 🔧 Useful Commands

```bash
# Check all services
docker-compose ps

# View API logs
docker-compose logs api

# View LocalStack logs
docker-compose logs localstack

# Check database
docker-compose exec db psql -U postgres -d interview_db -c "SELECT * FROM tasks;"

# Check Lambda
docker-compose exec localstack awslocal lambda list-functions

# Check SQS
docker-compose exec localstack awslocal sqs list-queues

# Restart everything
docker-compose restart

# Recreate Lambda
./setup_lambda.sh

# Run complete test
./test_end_to_end.sh
```

---

## 📚 Documentation Files

- **COMPLETE_TEST_GUIDE.md** - Detailed step-by-step testing guide
- **TEST_RESULTS_SUMMARY.md** - Test results and code locations
- **QUEUE_FLOW_EXPLAINED.md** - Complete queue workflow explanation
- **LAMBDA_COMMANDS.md** - All Lambda commands reference
- **LAMBDA_SETUP_GUIDE.md** - Lambda setup and configuration

---

## ✅ Quick Checklist

Before testing:
- [ ] Containers running: `docker-compose ps`
- [ ] Lambda exists: `docker-compose exec localstack awslocal lambda list-functions`
- [ ] Queue exists: `docker-compose exec localstack awslocal sqs list-queues`
- [ ] API healthy: `curl http://localhost:8000/health`

During test:
- [ ] Task created with ID
- [ ] Task status is "pending"
- [ ] Message appears in SQS queue
- [ ] Lambda receives message
- [ ] Queue becomes empty

After test:
- [ ] Task status changed (or manually update for demo)
- [ ] Queue is empty
- [ ] Result is saved

---

## 🎯 One-Line Test

```bash
./test_end_to_end.sh && echo "✅ Test complete!"
```

That's it! Everything you need to test and demonstrate the complete flow! 🚀
