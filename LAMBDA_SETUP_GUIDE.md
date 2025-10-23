# 🚀 Lambda Function Setup Guide

## ✅ Lambda Function Created Successfully!

Your Lambda function `task-processor` has been deployed to LocalStack.

### 📊 Current Status

```bash
# Check Lambda function
docker-compose exec localstack awslocal lambda list-functions

# Output:
# Function Name: task-processor
# Runtime: Python 3.9
# Handler: lambda_function.lambda_handler
# Timeout: 60 seconds
# Memory: 256 MB
# Status: Active
```

### 🔗 SQS Trigger Connected

```bash
# Check event source mapping
docker-compose exec localstack awslocal lambda list-event-source-mappings

# Output:
# UUID: 5858381c-fe8c-4a59-ab42-60b9a32c23cb
# State: Enabled
# Event Source: arn:aws:sqs:us-east-1:000000000000:interview-queue
```

## 🧪 Testing the Lambda Function

### Method 1: Via API (Recommended)

```bash
# Create a task (this sends message to SQS, which triggers Lambda)
curl -X POST http://localhost:8000/tasks \
  -H 'Content-Type: application/json' \
  -d '{"title":"Test Lambda","description":"Testing Lambda processing"}'

# Wait a few seconds for Lambda to process
sleep 5

# Check task status (should be "completed")
curl http://localhost:8000/tasks/5 | python3 -m json.tool
```

### Method 2: Direct SQS Message

```bash
# Send message directly to SQS
docker-compose exec localstack awslocal sqs send-message \
  --queue-url http://localhost:4566/000000000000/interview-queue \
  --message-body '{"task_id":1,"title":"Direct Test","description":"Testing"}'

# Lambda will automatically pick it up and process it
```

### Method 3: Manual Lambda Invocation

```bash
# Invoke Lambda function directly
docker-compose exec localstack awslocal lambda invoke \
  --function-name task-processor \
  --payload '{"Records":[{"body":"{\"task_id\":1,\"title\":\"Manual Test\"}"}]}' \
  /tmp/response.json

# View response
docker-compose exec localstack cat /tmp/response.json | python3 -m json.tool
```

## 📝 Lambda Function Details

### Environment Variables

The Lambda function has access to:
- `DB_HOST=db`
- `DB_NAME=interview_db`
- `DB_USER=postgres`
- `DB_PASSWORD=postgres`

### What the Lambda Does

1. **Receives** message from SQS queue
2. **Parses** task_id, title, description
3. **Updates** task status to "processing"
4. **Executes** business logic (process_task function)
5. **Updates** task status to "completed" with result
6. **Deletes** message from queue

### Code Flow

```python
def lambda_handler(event, context):
    for record in event['Records']:
        # Parse SQS message
        message = json.loads(record['body'])
        task_id = message['task_id']
        
        # Connect to database
        conn = psycopg2.connect(...)
        
        # Update to "processing"
        UPDATE tasks SET status = 'processing' WHERE id = task_id
        
        # Process task
        result = process_task(task_id, title, description)
        
        # Update to "completed"
        UPDATE tasks SET status = 'completed', result = result WHERE id = task_id
        
        return {'statusCode': 200}
```

## 🔧 Managing the Lambda Function

### Update Lambda Code

If you modify `lambda/lambda_function.py`:

```bash
# Re-run setup script
./setup_lambda.sh

# Or manually:
cd lambda && zip lambda.zip lambda_function.py && cd ..
docker cp lambda.zip interview_localstack:/tmp/lambda.zip
docker-compose exec localstack awslocal lambda update-function-code \
  --function-name task-processor \
  --zip-file fileb:///tmp/lambda.zip
```

### View Lambda Configuration

```bash
# Get full configuration
docker-compose exec localstack awslocal lambda get-function-configuration \
  --function-name task-processor | python3 -m json.tool
```

### Check Lambda Logs

```bash
# View Lambda logs (if available)
docker-compose exec localstack awslocal logs tail \
  /aws/lambda/task-processor \
  --follow
```

### Delete Lambda Function

```bash
# Delete function
docker-compose exec localstack awslocal lambda delete-function \
  --function-name task-processor

# Delete event source mapping
docker-compose exec localstack awslocal lambda delete-event-source-mapping \
  --uuid 5858381c-fe8c-4a59-ab42-60b9a32c23cb
```

## 🐛 Troubleshooting

### Lambda not processing messages

**Check event source mapping:**
```bash
docker-compose exec localstack awslocal lambda list-event-source-mappings \
  --function-name task-processor
```

Should show `State: Enabled`

**Check if messages are in queue:**
```bash
docker-compose exec localstack awslocal sqs get-queue-attributes \
  --queue-url http://localhost:4566/000000000000/interview-queue \
  --attribute-names ApproximateNumberOfMessages
```

**Manually invoke to test:**
```bash
docker-compose exec localstack awslocal lambda invoke \
  --function-name task-processor \
  --payload '{"Records":[{"body":"{\"task_id\":1,\"title\":\"Test\"}"}]}' \
  /tmp/response.json
```

### Database connection issues

**Check environment variables:**
```bash
docker-compose exec localstack awslocal lambda get-function-configuration \
  --function-name task-processor \
  --query 'Environment.Variables'
```

**Test database connection from API container:**
```bash
docker-compose exec api python -c "
import psycopg2
conn = psycopg2.connect(host='db', database='interview_db', user='postgres', password='postgres')
print('✓ Database connection successful')
conn.close()
"
```

### Lambda function not found

**Recreate the function:**
```bash
./setup_lambda.sh
```

## 📊 Complete Workflow Test

```bash
# 1. Create a task
TASK_ID=$(curl -s -X POST http://localhost:8000/tasks \
  -H 'Content-Type: application/json' \
  -d '{"title":"Complete Test"}' | grep -o '"id":[0-9]*' | grep -o '[0-9]*')

echo "Created task ID: $TASK_ID"

# 2. Check initial status (should be "pending")
curl -s http://localhost:8000/tasks/$TASK_ID | python3 -m json.tool

# 3. Wait for Lambda to process
echo "Waiting for Lambda to process..."
sleep 5

# 4. Check final status (should be "completed")
curl -s http://localhost:8000/tasks/$TASK_ID | python3 -m json.tool
```

## 🎯 Quick Commands

```bash
# List Lambda functions
docker-compose exec localstack awslocal lambda list-functions

# Get function details
docker-compose exec localstack awslocal lambda get-function --function-name task-processor

# List event mappings
docker-compose exec localstack awslocal lambda list-event-source-mappings

# Update function code
./setup_lambda.sh

# Test complete flow
./test_complete_flow.sh

# Interactive Lambda management
./lambda_commands.sh
```

## 📚 Related Documentation

- **QUEUE_FLOW_EXPLAINED.md** - Complete queue workflow explanation
- **LAMBDA_COMMANDS.md** - All Lambda commands reference
- **lambda_commands.sh** - Interactive Lambda management tool
- **setup_lambda.sh** - Lambda deployment script

## ⚠️ Important Notes

### LocalStack Limitations

1. **Not Persistent**: Lambda functions are lost on container restart
   - Re-run `./setup_lambda.sh` after `docker-compose down`

2. **Dependencies**: psycopg2 needs to be available in Lambda runtime
   - LocalStack may not have all Python packages pre-installed
   - For production, use Lambda Layers or package dependencies

3. **Async Processing**: Lambda may take a few seconds to process
   - SQS polls every few seconds
   - Not instant like production AWS

### Production Deployment

For real AWS Lambda:

1. **Package dependencies:**
   ```bash
   pip install -r lambda/requirements.txt -t lambda/package/
   cd lambda/package && zip -r ../lambda.zip . && cd ..
   zip -g lambda.zip lambda_function.py
   ```

2. **Deploy to AWS:**
   ```bash
   aws lambda create-function \
     --function-name task-processor \
     --runtime python3.9 \
     --handler lambda_function.lambda_handler \
     --role arn:aws:iam::ACCOUNT_ID:role/lambda-execution-role \
     --zip-file fileb://lambda.zip
   ```

3. **Create SQS trigger:**
   ```bash
   aws lambda create-event-source-mapping \
     --function-name task-processor \
     --event-source-arn arn:aws:sqs:REGION:ACCOUNT_ID:interview-queue
   ```

---

## ✅ Success Checklist

- [x] Lambda function created
- [x] SQS trigger connected
- [x] Environment variables configured
- [x] Function is active and enabled
- [ ] Test via API
- [ ] Test via SQS
- [ ] Test manual invocation
- [ ] Verify task status changes

**Your Lambda function is ready to process tasks! 🎉**
