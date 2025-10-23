# 🎯 Queue Flow - Quick Summary

## How Python Uses the Queue

### Simple Explanation

1. **API receives request** → Creates task in database (status: "pending")
2. **API sends message to SQS** → Using boto3 library
3. **SQS stores message** → Waits for Lambda to process
4. **Lambda receives message** → Automatically triggered by SQS
5. **Lambda processes task** → Updates database (status: "completed")
6. **Lambda deletes message** → Processing complete

### Key Python Code

#### 1. Sending Message (FastAPI)

```python
import boto3
import json

# Create SQS client
sqs = boto3.client('sqs', endpoint_url='http://localstack:4566')

# Send message
message = {"task_id": 1, "title": "Test Task"}
sqs.send_message(
    QueueUrl='http://localstack:4566/000000000000/interview-queue',
    MessageBody=json.dumps(message)
)
```

#### 2. Receiving Message (Lambda)

```python
def lambda_handler(event, context):
    # Parse message from SQS event
    for record in event['Records']:
        message = json.loads(record['body'])
        task_id = message['task_id']
        
        # Process task
        # Update database
        # Return success
```

### Test the Flow

```bash
# 1. Create a task
curl -X POST http://localhost:8000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title": "Test Task"}'

# 2. Check if message is in queue
docker-compose exec localstack awslocal sqs receive-message \
  --queue-url http://localhost:4566/000000000000/interview-queue

# 3. Run complete flow test
./test_complete_flow.sh
```

### Why Use a Queue?

✅ **Async Processing** - API responds immediately  
✅ **Scalability** - Lambda auto-scales based on queue depth  
✅ **Reliability** - Messages persist even if Lambda fails  
✅ **Decoupling** - API and processing are independent  
✅ **Retry Logic** - Automatic retries on failure  

### Complete Documentation

For detailed explanation, see: **QUEUE_FLOW_EXPLAINED.md**

---

**Quick Reference:**
- Send message: `boto3.client('sqs').send_message()`
- Receive message: Lambda triggered automatically
- Process: Update database, execute business logic
- Complete: Delete message from queue
