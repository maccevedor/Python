# 🔄 Complete Queue Flow Explanation

## Overview

This document explains how Python uses AWS SQS queue in the interview project, from API request to Lambda processing.

---

## 📊 Visual Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                    COMPLETE WORKFLOW                              │
└──────────────────────────────────────────────────────────────────┘

1. CLIENT REQUEST
   │
   ▼
   POST /tasks {"title": "Test Task"}
   │
   ▼
┌──────────────────────────────────────────────────────────────────┐
│ 2. FASTAPI APPLICATION (app/main.py)                             │
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ @app.post("/tasks")                                      │    │
│  │ async def create_task(task, db, sqs_client):            │    │
│  │                                                          │    │
│  │   Step 2a: Validate Input (Pydantic)                    │    │
│  │   ✓ title is not empty                                  │    │
│  │   ✓ description is optional                             │    │
│  │                                                          │    │
│  │   Step 2b: Create Task in Database                      │    │
│  │   db_task = Task(                                       │    │
│  │       title=task.title,                                 │    │
│  │       status=TaskStatus.PENDING                         │    │
│  │   )                                                      │    │
│  │   db.add(db_task)                                       │    │
│  │   db.commit()                                           │    │
│  │   # Task ID = 1, Status = "pending"                     │    │
│  │                                                          │    │
│  │   Step 2c: Send Message to SQS                          │    │
│  │   message = {                                           │    │
│  │       "task_id": 1,                                     │    │
│  │       "title": "Test Task",                             │    │
│  │       "description": null                               │    │
│  │   }                                                      │    │
│  │   sqs_client.send_message(message)                      │    │
│  │                                                          │    │
│  │   Step 2d: Return Response                              │    │
│  │   return TaskResponse(id=1, status="pending", ...)      │    │
│  └─────────────────────────────────────────────────────────┘    │
└────────────────┬──────────────────────┬──────────────────────────┘
                 │                      │
                 │                      │
        ┌────────▼────────┐    ┌────────▼─────────┐
        │   PostgreSQL    │    │   AWS SQS        │
        │   Database      │    │   Queue          │
        │                 │    │                  │
        │ tasks table:    │    │ Message:         │
        │ ┌─────────────┐ │    │ {                │
        │ │ id: 1       │ │    │   "task_id": 1,  │
        │ │ title: "..." │ │    │   "title": "..." │
        │ │ status:     │ │    │ }                │
        │ │ "pending"   │ │    │                  │
        │ └─────────────┘ │    │ Waiting for      │
        │                 │    │ consumer...      │
        └─────────────────┘    └────────┬─────────┘
                                        │
                                        │ 3. SQS Trigger
                                        │    (Event Source Mapping)
                                        ▼
                        ┌──────────────────────────────┐
                        │   AWS LAMBDA FUNCTION        │
                        │   (lambda/lambda_function.py)│
                        │                              │
                        │  lambda_handler(event):      │
                        │                              │
                        │  Step 3a: Receive Event      │
                        │  event = {                   │
                        │    "Records": [{             │
                        │      "body": "{...}"         │
                        │    }]                        │
                        │  }                           │
                        │                              │
                        │  Step 3b: Parse Message      │
                        │  message = json.loads(       │
                        │    record['body']            │
                        │  )                           │
                        │  task_id = 1                 │
                        │                              │
                        │  Step 3c: Update to          │
                        │            "processing"      │
                        │  UPDATE tasks                │
                        │  SET status = 'processing'   │
                        │  WHERE id = 1                │
                        │                              │
                        │  Step 3d: Process Task       │
                        │  result = process_task(...)  │
                        │  # Business logic here       │
                        │                              │
                        │  Step 3e: Update to          │
                        │            "completed"       │
                        │  UPDATE tasks                │
                        │  SET status = 'completed',   │
                        │      result = '...'          │
                        │  WHERE id = 1                │
                        │                              │
                        │  Step 3f: Return Success     │
                        │  return {                    │
                        │    'statusCode': 200         │
                        │  }                           │
                        └──────────────┬───────────────┘
                                       │
                                       │ 4. Update Database
                                       ▼
                        ┌──────────────────────────────┐
                        │   PostgreSQL Database        │
                        │                              │
                        │ tasks table (updated):       │
                        │ ┌──────────────────────────┐ │
                        │ │ id: 1                    │ │
                        │ │ title: "Test Task"       │ │
                        │ │ status: "completed"      │ │
                        │ │ result: "Processed..."   │ │
                        │ │ updated_at: 2025-10-23   │ │
                        │ └──────────────────────────┘ │
                        └──────────────────────────────┘
```

---

## 🔍 Detailed Code Flow

### 1. Client Makes Request

```bash
curl -X POST http://localhost:8000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Test Task"}'
```

**What happens:**
- HTTP POST request sent to FastAPI
- JSON body contains task data

---

### 2. FastAPI Processes Request

#### 2.1 Route Handler (`app/main.py`)

```python
@app.post("/tasks", response_model=TaskResponse, status_code=status.HTTP_201_CREATED)
async def create_task(
    task: TaskCreate,                    # Pydantic validates input
    db: Session = Depends(get_db),       # Database session injected
    sqs_client: SQSClient = Depends(get_sqs_client)  # SQS client injected
):
```

**Key Points:**
- `TaskCreate` - Pydantic model validates input
- `Depends(get_db)` - Dependency injection for database
- `Depends(get_sqs_client)` - Dependency injection for SQS

#### 2.2 Input Validation (`app/schemas.py`)

```python
class TaskCreate(BaseModel):
    title: str = Field(..., min_length=1, max_length=255)
    description: Optional[str] = None
```

**What it validates:**
- ✓ `title` exists and is not empty
- ✓ `title` is between 1-255 characters
- ✓ `description` is optional

#### 2.3 Create Database Record

```python
# Create task in database
db_task = Task(
    title=task.title,
    description=task.description,
    status=TaskStatus.PENDING  # Initial status
)
db.add(db_task)
db.commit()
db.refresh(db_task)  # Get the auto-generated ID
```

**Database State:**
```sql
INSERT INTO tasks (title, description, status, created_at)
VALUES ('Test Task', NULL, 'pending', '2025-10-23 19:58:03');
-- Returns: id = 1
```

#### 2.4 Send Message to SQS (`app/sqs_client.py`)

```python
# Prepare message
message = {
    "task_id": db_task.id,      # 1
    "title": db_task.title,      # "Test Task"
    "description": db_task.description  # null
}

# Send to SQS
sqs_client.send_message(message)
```

**SQS Client Implementation:**

```python
class SQSClient:
    def __init__(self):
        # Create boto3 SQS client
        self.client = boto3.client(
            'sqs',
            region_name='us-east-1',
            aws_access_key_id='test',
            aws_secret_access_key='test',
            endpoint_url='http://localstack:4566'  # LocalStack for dev
        )
        self.queue_url = 'http://localstack:4566/000000000000/interview-queue'
    
    def send_message(self, message_body: dict):
        # Convert dict to JSON string
        response = self.client.send_message(
            QueueUrl=self.queue_url,
            MessageBody=json.dumps(message_body)
        )
        return response
```

**What boto3 does:**
1. Converts message to JSON string
2. Makes HTTP POST to SQS endpoint
3. SQS stores message in queue
4. Returns MessageId

**SQS Message Structure:**
```json
{
  "MessageId": "abc123...",
  "MD5OfMessageBody": "...",
  "Body": "{\"task_id\": 1, \"title\": \"Test Task\", \"description\": null}"
}
```

#### 2.5 Return Response

```python
return db_task  # FastAPI serializes to TaskResponse
```

**Response to Client:**
```json
{
  "id": 1,
  "title": "Test Task",
  "description": null,
  "status": "pending",
  "created_at": "2025-10-23T19:58:03.884663Z",
  "updated_at": null,
  "result": null
}
```

---

### 3. AWS Lambda Processes Message

#### 3.1 Lambda Trigger

**In production:**
- SQS triggers Lambda automatically
- Event Source Mapping polls queue
- Lambda receives batches of messages

**Event Structure:**
```python
event = {
    "Records": [
        {
            "messageId": "abc123...",
            "receiptHandle": "xyz789...",
            "body": "{\"task_id\": 1, \"title\": \"Test Task\", \"description\": null}",
            "attributes": {...},
            "messageAttributes": {},
            "md5OfBody": "...",
            "eventSource": "aws:sqs",
            "eventSourceARN": "arn:aws:sqs:...",
            "awsRegion": "us-east-1"
        }
    ]
}
```

#### 3.2 Lambda Handler (`lambda/lambda_function.py`)

```python
def lambda_handler(event, context):
    """Process SQS messages"""
    
    for record in event['Records']:
        # Step 1: Parse message
        message_body = json.loads(record['body'])
        task_id = message_body.get('task_id')      # 1
        title = message_body.get('title')          # "Test Task"
        description = message_body.get('description')  # None
        
        # Step 2: Connect to database
        conn = psycopg2.connect(
            host='db',
            database='interview_db',
            user='postgres',
            password='postgres'
        )
        cursor = conn.cursor()
        
        # Step 3: Update status to PROCESSING
        cursor.execute(
            "UPDATE tasks SET status = %s, updated_at = %s WHERE id = %s",
            ('processing', datetime.now(), task_id)
        )
        conn.commit()
        
        # Step 4: Process the task (business logic)
        result = process_task(task_id, title, description)
        # result = "Processed task 'Test Task' at 2025-10-23..."
        
        # Step 5: Update status to COMPLETED
        cursor.execute(
            """
            UPDATE tasks 
            SET status = %s, result = %s, updated_at = %s 
            WHERE id = %s
            """,
            ('completed', result, datetime.now(), task_id)
        )
        conn.commit()
        
        # Step 6: Cleanup
        cursor.close()
        conn.close()
        
    # Step 7: Return success
    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'Processing complete'})
    }
```

#### 3.3 Business Logic

```python
def process_task(task_id, title, description):
    """
    This is where you implement your actual business logic
    Examples:
    - Send email
    - Generate report
    - Process data
    - Call external API
    - Perform calculations
    """
    result = f"Processed task '{title}' at {datetime.now().isoformat()}"
    
    if description:
        result += f" with description: {description}"
    
    # Simulate some work
    # time.sleep(2)  # In real scenario
    
    return result
```

---

## 🔄 Message Lifecycle

### 1. Message Creation
```python
# In FastAPI
message = {"task_id": 1, "title": "Test Task"}
sqs_client.send_message(message)
```

### 2. Message in Queue
```
SQS Queue State:
┌─────────────────────────────────────┐
│ Message ID: abc123                  │
│ Body: {"task_id": 1, ...}          │
│ Status: Available                   │
│ Visibility: Visible                 │
│ Receive Count: 0                    │
└─────────────────────────────────────┘
```

### 3. Message Received by Lambda
```
SQS Queue State:
┌─────────────────────────────────────┐
│ Message ID: abc123                  │
│ Body: {"task_id": 1, ...}          │
│ Status: In Flight                   │
│ Visibility: Hidden (30s timeout)    │
│ Receive Count: 1                    │
└─────────────────────────────────────┘
```

### 4. Message Processed Successfully
```
Lambda returns success → SQS deletes message
Queue is now empty
```

### 5. If Processing Fails
```
Visibility timeout expires (30s)
→ Message becomes visible again
→ Lambda retries (up to 3 times)
→ After max retries → Dead Letter Queue
```

---

## 🔧 Python Libraries Used

### 1. boto3 (AWS SDK for Python)

```python
import boto3

# Create SQS client
client = boto3.client('sqs', ...)

# Send message
client.send_message(QueueUrl='...', MessageBody='...')

# Receive message
client.receive_message(QueueUrl='...', MaxNumberOfMessages=10)

# Delete message
client.delete_message(QueueUrl='...', ReceiptHandle='...')
```

**What boto3 does:**
- Handles AWS authentication
- Makes HTTP requests to AWS APIs
- Serializes/deserializes data
- Manages retries and errors

### 2. psycopg2 (PostgreSQL Driver)

```python
import psycopg2

# Connect to database
conn = psycopg2.connect(host='db', database='interview_db', ...)

# Execute query
cursor = conn.cursor()
cursor.execute("UPDATE tasks SET status = %s WHERE id = %s", ('completed', 1))
conn.commit()
```

### 3. json (JSON Serialization)

```python
import json

# Serialize (Python → JSON string)
message_str = json.dumps({"task_id": 1})
# Result: '{"task_id": 1}'

# Deserialize (JSON string → Python)
message_dict = json.loads('{"task_id": 1}')
# Result: {'task_id': 1}
```

---

## 🎯 Complete Example with Actual Values

### Request
```bash
curl -X POST http://localhost:8000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Process User Data", "description": "Extract and transform"}'
```

### FastAPI Processing
```python
# 1. Pydantic validates
task = TaskCreate(title="Process User Data", description="Extract and transform")

# 2. Create in database
db_task = Task(id=5, title="Process User Data", status="pending")

# 3. Send to SQS
message = {
    "task_id": 5,
    "title": "Process User Data",
    "description": "Extract and transform"
}
boto3_client.send_message(
    QueueUrl="http://localstack:4566/000000000000/interview-queue",
    MessageBody='{"task_id": 5, "title": "Process User Data", "description": "Extract and transform"}'
)

# 4. Return response
return {"id": 5, "status": "pending", ...}
```

### SQS Queue
```json
{
  "Messages": [
    {
      "MessageId": "f7e8d9c0-...",
      "ReceiptHandle": "AQEBxyz...",
      "Body": "{\"task_id\": 5, \"title\": \"Process User Data\", \"description\": \"Extract and transform\"}"
    }
  ]
}
```

### Lambda Processing
```python
# 1. Receive event
event = {"Records": [{"body": "{\"task_id\": 5, ...}"}]}

# 2. Parse
message = json.loads(event['Records'][0]['body'])
# message = {'task_id': 5, 'title': 'Process User Data', ...}

# 3. Update database
UPDATE tasks SET status = 'processing' WHERE id = 5

# 4. Process
result = "Processed task 'Process User Data' at 2025-10-23T20:00:00"

# 5. Update database
UPDATE tasks SET status = 'completed', result = '...' WHERE id = 5

# 6. Return success
return {'statusCode': 200}
```

### Final Database State
```sql
SELECT * FROM tasks WHERE id = 5;

id | title              | status    | result                    | created_at | updated_at
---+--------------------+-----------+---------------------------+------------+------------
5  | Process User Data  | completed | Processed task 'Process...| 2025-10-23 | 2025-10-23
```

---

## 🚨 Error Handling

### Scenario 1: SQS Send Fails

```python
try:
    sqs_client.send_message(message)
except Exception as e:
    # Update task status to failed
    db_task.status = TaskStatus.FAILED
    db_task.result = f"Failed to send to SQS: {str(e)}"
    db.commit()
    raise HTTPException(status_code=500, detail=str(e))
```

### Scenario 2: Lambda Processing Fails

```python
try:
    # Process task
    result = process_task(task_id, title, description)
except Exception as e:
    # Update to failed status
    cursor.execute(
        "UPDATE tasks SET status = %s, result = %s WHERE id = %s",
        ('failed', f"Error: {str(e)}", task_id)
    )
    conn.commit()
```

### Scenario 3: Message Retry

```
Attempt 1: Lambda fails → Message returns to queue
Attempt 2: Lambda fails → Message returns to queue
Attempt 3: Lambda fails → Message moves to Dead Letter Queue
```

---

## 📊 Performance Characteristics

### Latency
- **API Response**: < 100ms (just saves to DB and sends to SQS)
- **SQS Send**: < 50ms
- **Lambda Trigger**: 1-5 seconds (polling interval)
- **Lambda Processing**: Depends on business logic
- **Total Time**: API returns immediately, processing happens async

### Scalability
- **API**: Can handle thousands of requests/second
- **SQS**: Unlimited throughput
- **Lambda**: Auto-scales to process messages
- **Database**: Connection pooling handles concurrent updates

---

## 🎓 Key Concepts

### 1. Asynchronous Processing
- API doesn't wait for processing to complete
- Returns immediately with "pending" status
- Processing happens in background

### 2. Decoupling
- API and processing are separate
- Can scale independently
- Failures don't affect each other

### 3. Reliability
- Messages persist in SQS
- Automatic retries on failure
- Dead letter queue for failed messages

### 4. Scalability
- Lambda auto-scales based on queue depth
- Can process thousands of messages in parallel
- No server management needed

---

## 🔍 Debugging Tips

### Check if message was sent
```bash
docker-compose exec localstack awslocal sqs receive-message \
  --queue-url http://localhost:4566/000000000000/interview-queue
```

### Check task status
```bash
curl http://localhost:8000/tasks/1
```

### View SQS queue attributes
```bash
docker-compose exec localstack awslocal sqs get-queue-attributes \
  --queue-url http://localhost:4566/000000000000/interview-queue \
  --attribute-names All
```

### Check database directly
```bash
docker-compose exec db psql -U postgres -d interview_db \
  -c "SELECT id, title, status, result FROM tasks;"
```

---

## 📚 Summary

**The complete flow:**
1. Client sends POST request
2. FastAPI validates and saves to database (status: pending)
3. FastAPI sends message to SQS queue
4. FastAPI returns response immediately
5. Lambda polls SQS and receives message
6. Lambda updates status to "processing"
7. Lambda executes business logic
8. Lambda updates status to "completed" with result
9. Lambda deletes message from queue

**Key Python components:**
- **boto3**: AWS SDK for sending/receiving messages
- **psycopg2**: PostgreSQL driver for database operations
- **json**: Serialization/deserialization
- **FastAPI**: Web framework with dependency injection
- **Pydantic**: Data validation

**Benefits:**
- ✅ Fast API responses
- ✅ Scalable processing
- ✅ Reliable message delivery
- ✅ Automatic retries
- ✅ Decoupled architecture

---

**Ready to test?** Try creating a task and watch it flow through the system!
