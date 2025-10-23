# 🧪 Complete Testing Guide - Task Creation to Lambda Processing

This guide shows **exactly** where each piece of code runs when you create a task.

---

## 📋 Step-by-Step Test Process

### Step 1: Create a New Task via API

**Command:**
```bash
curl -X POST http://localhost:8000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Lambda Flow","description":"Watch the complete process"}'
```

**Expected Response:**
```json
{
  "id": 6,
  "title": "Test Lambda Flow",
  "description": "Watch the complete process",
  "status": "pending",
  "created_at": "2025-10-23T20:20:00.000000Z",
  "updated_at": null,
  "result": null
}
```

**💡 Note the Task ID** - You'll use it to check status later (e.g., `id: 6`)

---

### Step 2: Check Initial Task Status

**Command:**
```bash
# Replace 6 with your task ID
curl http://localhost:8000/tasks/6 | python3 -m json.tool
```

**Expected Output:**
```json
{
  "id": 6,
  "status": "pending",  ← Still pending
  "result": null
}
```

---

### Step 3: Check SQS Queue for Message

**Command:**
```bash
docker-compose exec localstack awslocal sqs receive-message \
  --queue-url http://localhost:4566/000000000000/interview-queue \
  --max-number-of-messages 1
```

**Expected Output:**
```json
{
  "Messages": [
    {
      "MessageId": "abc123...",
      "Body": "{\"task_id\": 6, \"title\": \"Test Lambda Flow\", \"description\": \"Watch the complete process\"}"
    }
  ]
}
```

**💡 If empty:** Lambda already processed it! Skip to Step 5.

---

### Step 4: Wait for Lambda to Process

**Command:**
```bash
# Wait 5-10 seconds for Lambda to pick up the message
sleep 10
```

**What's happening:**
- LocalStack polls SQS every few seconds
- Lambda receives the message
- Lambda processes the task
- Lambda updates the database
- Lambda deletes the message

---

### Step 5: Check Final Task Status

**Command:**
```bash
curl http://localhost:8000/tasks/6 | python3 -m json.tool
```

**Expected Output:**
```json
{
  "id": 6,
  "status": "completed",  ← Changed to completed!
  "result": "Processed task 'Test Lambda Flow' at 2025-10-23T20:20:10...",
  "updated_at": "2025-10-23T20:20:10.123456Z"
}
```

---

### Step 6: Verify Queue is Empty

**Command:**
```bash
docker-compose exec localstack awslocal sqs get-queue-attributes \
  --queue-url http://localhost:4566/000000000000/interview-queue \
  --attribute-names ApproximateNumberOfMessages
```

**Expected Output:**
```json
{
  "Attributes": {
    "ApproximateNumberOfMessages": "0"  ← Queue is empty
  }
}
```

---

## 🔍 Where Each Code Executes

### 📍 Location 1: FastAPI Application (`app/main.py`)

**When:** Step 1 - When you POST to `/tasks`

**File:** `/home/mrueda/WWW/interview/python/app/main.py`

**Code Location:** Lines 39-75

```python
@app.post("/tasks", response_model=TaskResponse, status_code=status.HTTP_201_CREATED)
async def create_task(
    task: TaskCreate,
    db: Session = Depends(get_db),
    sqs_client: SQSClient = Depends(get_sqs_client)
):
    """Create a new task and send it to SQS for processing"""
    
    # ✅ STEP 1: Create task in database
    db_task = Task(
        title=task.title,
        description=task.description,
        status=TaskStatus.PENDING  # ← Status starts as "pending"
    )
    db.add(db_task)
    db.commit()
    db.refresh(db_task)
    
    # ✅ STEP 2: Send message to SQS
    try:
        message = {
            "task_id": db_task.id,      # ← Task ID
            "title": db_task.title,
            "description": db_task.description
        }
        sqs_client.send_message(message)  # ← Sends to SQS
    except Exception as e:
        # If SQS fails, mark task as failed
        db_task.status = TaskStatus.FAILED
        db_task.result = f"Failed to send to SQS: {str(e)}"
        db.commit()
        raise HTTPException(status_code=500, detail=str(e))
    
    # ✅ STEP 3: Return response to client
    return db_task
```

**What happens here:**
1. ✅ Validates input (Pydantic)
2. ✅ Creates task in PostgreSQL (status: "pending")
3. ✅ Sends message to SQS queue
4. ✅ Returns response immediately (doesn't wait for processing)

---

### 📍 Location 2: SQS Client (`app/sqs_client.py`)

**When:** Step 1 - Inside `create_task` function

**File:** `/home/mrueda/WWW/interview/python/app/sqs_client.py`

**Code Location:** Lines 19-29

```python
def send_message(self, message_body: dict):
    """Send a message to SQS queue"""
    try:
        # ✅ Convert Python dict to JSON string
        response = self.client.send_message(
            QueueUrl=self.queue_url,  # ← http://localstack:4566/.../interview-queue
            MessageBody=json.dumps(message_body)  # ← {"task_id": 6, "title": "..."}
        )
        return response
    except Exception as e:
        print(f"Error sending message to SQS: {e}")
        raise
```

**What happens here:**
1. ✅ Converts message to JSON string
2. ✅ Uses boto3 to send to SQS
3. ✅ SQS stores the message
4. ✅ Returns MessageId

---

### 📍 Location 3: AWS SQS Queue (LocalStack)

**When:** After Step 1

**Location:** LocalStack container

**State:**
```
Queue: interview-queue
Message: {
  "MessageId": "abc123...",
  "Body": "{\"task_id\": 6, \"title\": \"Test Lambda Flow\", ...}",
  "Status": "Available"
}
```

**What happens here:**
1. ✅ Message is stored in queue
2. ✅ Waiting for Lambda to poll
3. ✅ Message is visible and available

---

### 📍 Location 4: Lambda Function (`lambda/lambda_function.py`)

**When:** Step 4 - Lambda automatically polls SQS

**File:** `/home/mrueda/WWW/interview/python/lambda/lambda_function.py`

**Code Location:** Lines 31-117

```python
def lambda_handler(event, context):
    """
    AWS Lambda handler function
    Processes messages from SQS queue and updates task status in PostgreSQL
    """
    print(f"Received event: {json.dumps(event)}")
    
    processed_records = []
    failed_records = []
    
    # ✅ STEP 1: Loop through SQS messages
    for record in event['Records']:
        try:
            # ✅ STEP 2: Parse SQS message
            message_body = json.loads(record['body'])
            task_id = message_body.get('task_id')      # ← 6
            title = message_body.get('title')          # ← "Test Lambda Flow"
            description = message_body.get('description')
            
            print(f"Processing task {task_id}: {title}")
            
            # ✅ STEP 3: Connect to database
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # ✅ STEP 4: Update task status to PROCESSING
            cursor.execute(
                "UPDATE tasks SET status = %s, updated_at = %s WHERE id = %s",
                ('processing', datetime.now(), task_id)
            )
            conn.commit()
            
            # ✅ STEP 5: Process the task (business logic)
            result = process_task(task_id, title, description)
            # result = "Processed task 'Test Lambda Flow' at 2025-10-23..."
            
            # ✅ STEP 6: Update task status to COMPLETED
            cursor.execute(
                """
                UPDATE tasks 
                SET status = %s, result = %s, updated_at = %s 
                WHERE id = %s
                """,
                ('completed', result, datetime.now(), task_id)
            )
            conn.commit()
            
            # ✅ STEP 7: Cleanup
            cursor.close()
            conn.close()
            
            processed_records.append(task_id)
            print(f"Successfully processed task {task_id}")
            
        except Exception as e:
            # Handle errors
            error_msg = str(e)
            print(f"Error processing record: {error_msg}")
            failed_records.append({
                'task_id': task_id if 'task_id' in locals() else 'unknown',
                'error': error_msg
            })
            
            # Try to update task status to FAILED
            try:
                conn = get_db_connection()
                cursor = conn.cursor()
                cursor.execute(
                    """
                    UPDATE tasks 
                    SET status = %s, result = %s, updated_at = %s 
                    WHERE id = %s
                    """,
                    ('failed', f"Error: {error_msg}", datetime.now(), task_id)
                )
                conn.commit()
                cursor.close()
                conn.close()
            except Exception as db_error:
                print(f"Failed to update task status: {db_error}")
    
    # ✅ STEP 8: Return success response
    response = {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Processing complete',
            'processed': processed_records,
            'failed': failed_records
        })
    }
    
    return response
```

**What happens here:**
1. ✅ Receives event from SQS (automatic trigger)
2. ✅ Parses message body
3. ✅ Connects to PostgreSQL database
4. ✅ Updates status to "processing"
5. ✅ Executes business logic
6. ✅ Updates status to "completed" with result
7. ✅ Returns success (SQS auto-deletes message)

---

### 📍 Location 5: Business Logic (`lambda/lambda_function.py`)

**When:** Inside Lambda processing

**File:** `/home/mrueda/WWW/interview/python/lambda/lambda_function.py`

**Code Location:** Lines 17-28

```python
def process_task(task_id, title, description):
    """
    Process the task - This is where you would implement your business logic
    For this example, we'll just simulate processing and update the task status
    """
    # ✅ This is where you add your custom logic
    # Examples:
    # - Send email
    # - Generate report
    # - Call external API
    # - Process data
    # - Perform calculations
    
    result = f"Processed task '{title}' at {datetime.now().isoformat()}"
    
    if description:
        result += f" with description: {description}"
    
    return result
```

**What happens here:**
1. ✅ Executes your custom business logic
2. ✅ Returns result string
3. ✅ Result is saved to database

---

## 🎬 Complete Test Script

Run this to see the entire flow:

```bash
#!/bin/bash

echo "🧪 Testing Complete Flow: API → SQS → Lambda → Database"
echo "=========================================================="
echo ""

# Step 1: Create task
echo "📝 Step 1: Creating task via API..."
RESPONSE=$(curl -s -X POST http://localhost:8000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Complete Flow Test","description":"Testing end-to-end"}')

TASK_ID=$(echo $RESPONSE | grep -o '"id":[0-9]*' | grep -o '[0-9]*')
echo "✅ Task created with ID: $TASK_ID"
echo "Response: $RESPONSE"
echo ""

# Step 2: Check initial status
echo "📊 Step 2: Checking initial task status..."
curl -s http://localhost:8000/tasks/$TASK_ID | python3 -m json.tool
echo ""

# Step 3: Check SQS queue
echo "📬 Step 3: Checking SQS queue..."
SQS_MSG=$(docker-compose exec -T localstack awslocal sqs receive-message \
  --queue-url http://localhost:4566/000000000000/interview-queue \
  --max-number-of-messages 1 2>/dev/null)

if echo "$SQS_MSG" | grep -q "MessageId"; then
    echo "✅ Message found in queue!"
    echo "$SQS_MSG" | python3 -m json.tool
else
    echo "⚠️  Queue is empty (Lambda may have already processed it)"
fi
echo ""

# Step 4: Wait for Lambda
echo "⏳ Step 4: Waiting for Lambda to process (10 seconds)..."
sleep 10
echo ""

# Step 5: Check final status
echo "🎯 Step 5: Checking final task status..."
FINAL=$(curl -s http://localhost:8000/tasks/$TASK_ID)
echo "$FINAL" | python3 -m json.tool
echo ""

# Step 6: Verify queue is empty
echo "📭 Step 6: Verifying queue is empty..."
QUEUE_COUNT=$(docker-compose exec -T localstack awslocal sqs get-queue-attributes \
  --queue-url http://localhost:4566/000000000000/interview-queue \
  --attribute-names ApproximateNumberOfMessages \
  --query 'Attributes.ApproximateNumberOfMessages' \
  --output text 2>/dev/null)

echo "Messages in queue: $QUEUE_COUNT"
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Test Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if successful
if echo "$FINAL" | grep -q '"status": "completed"'; then
    echo "🎉 SUCCESS! Task was processed by Lambda"
    echo ""
    echo "Flow summary:"
    echo "  1. ✅ API created task (status: pending)"
    echo "  2. ✅ API sent message to SQS"
    echo "  3. ✅ Lambda received message from SQS"
    echo "  4. ✅ Lambda processed task"
    echo "  5. ✅ Lambda updated status to completed"
    echo "  6. ✅ Lambda deleted message from queue"
else
    echo "⚠️  Task status: $(echo $FINAL | grep -o '"status": "[^"]*"')"
    echo ""
    echo "Troubleshooting:"
    echo "  • Check Lambda logs: docker-compose logs localstack"
    echo "  • Verify Lambda exists: docker-compose exec localstack awslocal lambda list-functions"
    echo "  • Check event mapping: docker-compose exec localstack awslocal lambda list-event-source-mappings"
fi
echo ""
```

Save this as `test_end_to_end.sh` and run:

```bash
chmod +x test_end_to_end.sh
./test_end_to_end.sh
```

---

## 📊 Code Execution Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ YOU RUN: curl -X POST http://localhost:8000/tasks              │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 📍 LOCATION 1: app/main.py (Lines 39-75)                        │
│                                                                  │
│ @app.post("/tasks")                                             │
│ async def create_task(...):                                     │
│     db_task = Task(status=TaskStatus.PENDING)  ← Create in DB  │
│     db.commit()                                                 │
│     sqs_client.send_message(message)           ← Send to SQS    │
│     return db_task                             ← Return to you  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 📍 LOCATION 2: app/sqs_client.py (Lines 19-29)                  │
│                                                                  │
│ def send_message(self, message_body: dict):                     │
│     response = self.client.send_message(                        │
│         QueueUrl=self.queue_url,                                │
│         MessageBody=json.dumps(message_body)                    │
│     )                                                            │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 📍 LOCATION 3: AWS SQS Queue (LocalStack)                       │
│                                                                  │
│ Message stored in queue:                                        │
│ {                                                                │
│   "MessageId": "abc123",                                        │
│   "Body": "{\"task_id\": 6, \"title\": \"...\"}"               │
│ }                                                                │
│                                                                  │
│ Status: Available, waiting for Lambda...                        │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             │ (Lambda polls every few seconds)
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 📍 LOCATION 4: lambda/lambda_function.py (Lines 31-117)         │
│                                                                  │
│ def lambda_handler(event, context):                             │
│     for record in event['Records']:                             │
│         message = json.loads(record['body'])                    │
│         task_id = message['task_id']                            │
│                                                                  │
│         # Connect to database                                   │
│         conn = psycopg2.connect(...)                            │
│                                                                  │
│         # Update to "processing"                                │
│         UPDATE tasks SET status = 'processing' WHERE id = ...   │
│                                                                  │
│         # Process task                                          │
│         result = process_task(task_id, title, description)      │
│                                                                  │
│         # Update to "completed"                                 │
│         UPDATE tasks SET status = 'completed' WHERE id = ...    │
│                                                                  │
│     return {'statusCode': 200}                                  │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 📍 LOCATION 5: lambda/lambda_function.py (Lines 17-28)          │
│                                                                  │
│ def process_task(task_id, title, description):                  │
│     # YOUR BUSINESS LOGIC HERE                                  │
│     result = f"Processed task '{title}' at {datetime.now()}"   │
│     return result                                                │
└────────────────────────────┬────────────────────────────────────┘
                             │
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│ 📍 PostgreSQL Database                                          │
│                                                                  │
│ Task updated:                                                    │
│ - status: "completed"                                           │
│ - result: "Processed task '...' at 2025-10-23..."              │
│ - updated_at: 2025-10-23T20:20:10                              │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔍 Quick Verification Commands

```bash
# 1. Check Lambda function exists
docker-compose exec localstack awslocal lambda list-functions \
  --query 'Functions[*].FunctionName'

# 2. Check SQS trigger is connected
docker-compose exec localstack awslocal lambda list-event-source-mappings \
  --query 'EventSourceMappings[*].[FunctionArn,State]'

# 3. Check queue status
docker-compose exec localstack awslocal sqs get-queue-attributes \
  --queue-url http://localhost:4566/000000000000/interview-queue \
  --attribute-names All

# 4. List all tasks
curl http://localhost:8000/tasks | python3 -m json.tool

# 5. Check specific task
curl http://localhost:8000/tasks/6 | python3 -m json.tool
```

---

## 🎯 Summary

**Code Locations:**
1. **API Handler**: `app/main.py` lines 39-75
2. **SQS Client**: `app/sqs_client.py` lines 19-29
3. **Lambda Handler**: `lambda/lambda_function.py` lines 31-117
4. **Business Logic**: `lambda/lambda_function.py` lines 17-28

**Process:**
1. API creates task → Database (pending)
2. API sends message → SQS
3. Lambda receives → Processes → Updates DB (completed)
4. Lambda deletes message → Queue empty

**Test it now:**
```bash
./test_end_to_end.sh
```

🎉 **You're ready to test the complete flow!**
