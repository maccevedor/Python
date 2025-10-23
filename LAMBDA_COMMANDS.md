# 🔧 Lambda Commands Reference

## Quick Commands

### List Lambda Functions

```bash
# Basic list
docker-compose exec localstack awslocal lambda list-functions

# Pretty formatted
docker-compose exec localstack awslocal lambda list-functions | python3 -m json.tool

# Only function names
docker-compose exec localstack awslocal lambda list-functions \
  --query 'Functions[*].FunctionName' \
  --output text

# Table format
docker-compose exec localstack awslocal lambda list-functions \
  --query 'Functions[*].[FunctionName,Runtime,Handler]' \
  --output table
```

### Get Function Details

```bash
# Get complete function info
docker-compose exec localstack awslocal lambda get-function \
  --function-name task-processor

# Get only configuration
docker-compose exec localstack awslocal lambda get-function-configuration \
  --function-name task-processor

# Get code location
docker-compose exec localstack awslocal lambda get-function \
  --function-name task-processor \
  --query 'Code.Location'
```

### List Event Source Mappings (SQS Triggers)

```bash
# List all mappings
docker-compose exec localstack awslocal lambda list-event-source-mappings

# For specific function
docker-compose exec localstack awslocal lambda list-event-source-mappings \
  --function-name task-processor

# Table format
docker-compose exec localstack awslocal lambda list-event-source-mappings \
  --query 'EventSourceMappings[*].[UUID,FunctionArn,State]' \
  --output table
```

## Create Lambda Function

### Step 1: Package the Code

```bash
# Zip the lambda code
cd lambda
zip -r ../lambda.zip .
cd ..
```

### Step 2: Create Function

```bash
docker-compose exec localstack awslocal lambda create-function \
  --function-name task-processor \
  --runtime python3.9 \
  --handler lambda_function.lambda_handler \
  --role arn:aws:iam::000000000000:role/lambda-role \
  --zip-file fileb://lambda.zip \
  --environment Variables="{DB_HOST=db,DB_NAME=interview_db,DB_USER=postgres,DB_PASSWORD=postgres}"
```

### Step 3: Create Event Source Mapping (SQS Trigger)

```bash
# Get queue ARN
QUEUE_ARN=$(docker-compose exec -T localstack awslocal sqs get-queue-attributes \
  --queue-url http://localhost:4566/000000000000/interview-queue \
  --attribute-names QueueArn \
  --query 'Attributes.QueueArn' \
  --output text)

# Create mapping
docker-compose exec localstack awslocal lambda create-event-source-mapping \
  --function-name task-processor \
  --event-source-arn "$QUEUE_ARN" \
  --batch-size 10
```

## Invoke Lambda Function

### Manual Invocation

```bash
# Create test payload
PAYLOAD='{"Records":[{"body":"{\"task_id\":1,\"title\":\"Test Task\"}"}]}'

# Invoke function
docker-compose exec localstack awslocal lambda invoke \
  --function-name task-processor \
  --payload "$PAYLOAD" \
  /tmp/response.json

# View response
docker-compose exec localstack cat /tmp/response.json
```

### Invoke with File

```bash
# Create payload file
cat > payload.json << 'EOF'
{
  "Records": [
    {
      "body": "{\"task_id\": 1, \"title\": \"Test Task\", \"description\": \"Testing\"}"
    }
  ]
}
EOF

# Invoke
docker-compose exec localstack awslocal lambda invoke \
  --function-name task-processor \
  --payload file://payload.json \
  response.json
```

## Update Lambda Function

### Update Code

```bash
# Repackage
cd lambda && zip -r ../lambda.zip . && cd ..

# Update
docker-compose exec localstack awslocal lambda update-function-code \
  --function-name task-processor \
  --zip-file fileb://lambda.zip
```

### Update Configuration

```bash
# Update environment variables
docker-compose exec localstack awslocal lambda update-function-configuration \
  --function-name task-processor \
  --environment Variables="{DB_HOST=db,DB_NAME=interview_db}"

# Update timeout
docker-compose exec localstack awslocal lambda update-function-configuration \
  --function-name task-processor \
  --timeout 60

# Update memory
docker-compose exec localstack awslocal lambda update-function-configuration \
  --function-name task-processor \
  --memory-size 512
```

## Delete Lambda Function

```bash
# Delete function
docker-compose exec localstack awslocal lambda delete-function \
  --function-name task-processor

# Delete event source mapping
docker-compose exec localstack awslocal lambda delete-event-source-mapping \
  --uuid MAPPING_UUID
```

## Get Lambda Logs

```bash
# List log streams
docker-compose exec localstack awslocal logs describe-log-streams \
  --log-group-name /aws/lambda/task-processor

# Get latest logs
docker-compose exec localstack awslocal logs tail \
  /aws/lambda/task-processor \
  --follow
```

## Helper Script

Use the interactive helper script:

```bash
# Interactive menu
./lambda_commands.sh

# Direct commands
./lambda_commands.sh list          # List functions
./lambda_commands.sh details       # Get details
./lambda_commands.sh mappings      # List event mappings
./lambda_commands.sh invoke        # Invoke function
./lambda_commands.sh create        # Create function
./lambda_commands.sh update        # Update code
./lambda_commands.sh commands      # Show all commands
```

## Common Workflows

### 1. Deploy New Lambda

```bash
# Package
cd lambda && zip -r ../lambda.zip . && cd ..

# Create
docker-compose exec localstack awslocal lambda create-function \
  --function-name task-processor \
  --runtime python3.9 \
  --handler lambda_function.lambda_handler \
  --role arn:aws:iam::000000000000:role/lambda-role \
  --zip-file fileb://lambda.zip

# Connect to SQS
QUEUE_ARN=$(docker-compose exec -T localstack awslocal sqs get-queue-attributes \
  --queue-url http://localhost:4566/000000000000/interview-queue \
  --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)

docker-compose exec localstack awslocal lambda create-event-source-mapping \
  --function-name task-processor \
  --event-source-arn "$QUEUE_ARN"
```

### 2. Update Existing Lambda

```bash
# Update code
cd lambda && zip -r ../lambda.zip . && cd ..
docker-compose exec localstack awslocal lambda update-function-code \
  --function-name task-processor \
  --zip-file fileb://lambda.zip
```

### 3. Test Lambda

```bash
# Send message to SQS (triggers Lambda)
docker-compose exec localstack awslocal sqs send-message \
  --queue-url http://localhost:4566/000000000000/interview-queue \
  --message-body '{"task_id": 1, "title": "Test"}'

# Or invoke directly
docker-compose exec localstack awslocal lambda invoke \
  --function-name task-processor \
  --payload '{"Records":[{"body":"{\"task_id\":1}"}]}' \
  response.json
```

### 4. Debug Lambda

```bash
# Check if function exists
docker-compose exec localstack awslocal lambda list-functions

# Check event source mapping
docker-compose exec localstack awslocal lambda list-event-source-mappings

# Check logs
docker-compose exec localstack awslocal logs tail /aws/lambda/task-processor

# Check function configuration
docker-compose exec localstack awslocal lambda get-function-configuration \
  --function-name task-processor
```

## Troubleshooting

### Function not found

```bash
# List all functions
docker-compose exec localstack awslocal lambda list-functions

# Create if missing
./lambda_commands.sh create
```

### Function not triggered by SQS

```bash
# Check event source mapping
docker-compose exec localstack awslocal lambda list-event-source-mappings

# Verify mapping state is "Enabled"
# If not, create mapping:
QUEUE_ARN=$(docker-compose exec -T localstack awslocal sqs get-queue-attributes \
  --queue-url http://localhost:4566/000000000000/interview-queue \
  --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)

docker-compose exec localstack awslocal lambda create-event-source-mapping \
  --function-name task-processor \
  --event-source-arn "$QUEUE_ARN"
```

### Code changes not reflected

```bash
# Update function code
cd lambda && zip -r ../lambda.zip . && cd ..
docker-compose exec localstack awslocal lambda update-function-code \
  --function-name task-processor \
  --zip-file fileb://lambda.zip
```

## Quick Reference Table

| Command | Description |
|---------|-------------|
| `list-functions` | List all Lambda functions |
| `get-function` | Get function details |
| `get-function-configuration` | Get function config only |
| `create-function` | Create new function |
| `update-function-code` | Update function code |
| `update-function-configuration` | Update function settings |
| `delete-function` | Delete function |
| `invoke` | Invoke function manually |
| `list-event-source-mappings` | List SQS triggers |
| `create-event-source-mapping` | Connect SQS to Lambda |
| `delete-event-source-mapping` | Remove SQS trigger |

## Environment Variables for Lambda

```bash
docker-compose exec localstack awslocal lambda update-function-configuration \
  --function-name task-processor \
  --environment Variables="{
    DB_HOST=db,
    DB_NAME=interview_db,
    DB_USER=postgres,
    DB_PASSWORD=postgres,
    AWS_REGION=us-east-1
  }"
```

---

**Note:** In LocalStack, Lambda functions are not persistent across container restarts. You'll need to recreate them after `docker-compose down`.

For production AWS, replace `awslocal` with `aws` and remove `--endpoint-url`.
