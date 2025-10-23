#!/bin/bash

# Setup Lambda Function with pg8000 (pure Python PostgreSQL driver)
# This avoids psycopg2 compilation issues in LocalStack

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "🚀 Setting up Lambda Function with pg8000"
echo "=========================================="
echo ""

# Step 1: Check if containers are running
echo -e "${BLUE}Step 1: Checking containers...${NC}"
if ! docker-compose ps | grep -q "Up"; then
    echo -e "${RED}Error: Containers are not running${NC}"
    echo "Run: docker-compose up -d"
    exit 1
fi
echo -e "${GREEN}✓ Containers are running${NC}"
echo ""

# Step 2: Create temporary directory and install dependencies
echo -e "${BLUE}Step 2: Installing pg8000 (pure Python driver)...${NC}"
rm -rf /tmp/lambda-package
mkdir -p /tmp/lambda-package

# Install pg8000 - pure Python, no C extensions
pip3 install pg8000==1.30.3 scramp -t /tmp/lambda-package/ --quiet --no-cache-dir

echo -e "${GREEN}✓ pg8000 installed${NC}"
echo ""

# Step 3: Copy Lambda function
echo -e "${BLUE}Step 3: Packaging Lambda function...${NC}"

# Use the pg8000 version
cp lambda/lambda_function_pg8000.py /tmp/lambda-package/lambda_function.py

# Create zip file
cd /tmp/lambda-package
zip -r /tmp/lambda-fixed.zip . > /dev/null 2>&1
cd - > /dev/null

PACKAGE_SIZE=$(du -h /tmp/lambda-fixed.zip | cut -f1)
echo -e "${GREEN}✓ Lambda function packaged${NC}"
echo "Package size: $PACKAGE_SIZE"
echo ""

# Step 4: Copy to LocalStack
echo -e "${BLUE}Step 4: Copying package to LocalStack...${NC}"
docker cp /tmp/lambda-fixed.zip interview_localstack:/tmp/lambda.zip
echo -e "${GREEN}✓ Package copied${NC}"
echo ""

# Step 5: Update Lambda function
echo -e "${BLUE}Step 5: Updating Lambda function...${NC}"

# Check if function exists
EXISTING=$(docker-compose exec -T localstack awslocal lambda list-functions \
    --query 'Functions[?FunctionName==`task-processor`].FunctionName' \
    --output text 2>/dev/null || echo "")

if [ ! -z "$EXISTING" ]; then
    echo "Updating existing function..."
    docker-compose exec -T localstack awslocal lambda update-function-code \
        --function-name task-processor \
        --zip-file fileb:///tmp/lambda.zip > /dev/null
    echo -e "${GREEN}✓ Lambda function updated${NC}"
else
    echo "Creating new function..."
    docker-compose exec -T localstack awslocal lambda create-function \
        --function-name task-processor \
        --runtime python3.9 \
        --handler lambda_function.lambda_handler \
        --role arn:aws:iam::000000000000:role/lambda-role \
        --zip-file fileb:///tmp/lambda.zip \
        --timeout 60 \
        --memory-size 256 \
        --environment Variables="{DB_HOST=db,DB_NAME=interview_db,DB_USER=postgres,DB_PASSWORD=postgres,DB_PORT=5432}" \
        > /dev/null
    echo -e "${GREEN}✓ Lambda function created${NC}"
fi
echo ""

# Step 6: Ensure event source mapping
echo -e "${BLUE}Step 6: Checking SQS trigger...${NC}"

QUEUE_ARN=$(docker-compose exec -T localstack awslocal sqs get-queue-attributes \
    --queue-url http://localhost:4566/000000000000/interview-queue \
    --attribute-names QueueArn \
    --query 'Attributes.QueueArn' \
    --output text 2>/dev/null | tr -d '\r')

if [ -z "$QUEUE_ARN" ]; then
    echo -e "${RED}Error: Queue not found${NC}"
    exit 1
fi

EXISTING_MAPPING=$(docker-compose exec -T localstack awslocal lambda list-event-source-mappings \
    --function-name task-processor \
    --query 'EventSourceMappings[0].UUID' \
    --output text 2>/dev/null || echo "")

if [ ! -z "$EXISTING_MAPPING" ] && [ "$EXISTING_MAPPING" != "None" ]; then
    echo -e "${GREEN}✓ Event source mapping exists${NC}"
else
    docker-compose exec -T localstack awslocal lambda create-event-source-mapping \
        --function-name task-processor \
        --event-source-arn "$QUEUE_ARN" \
        --batch-size 10 \
        --enabled > /dev/null
    echo -e "${GREEN}✓ Event source mapping created${NC}"
fi
echo ""

# Step 7: Test Lambda function
echo -e "${BLUE}Step 7: Testing Lambda function...${NC}"

# First, create a test task in the database
echo "Creating test task in database..."
docker-compose exec -T db psql -U postgres -d interview_db -c \
    "INSERT INTO tasks (title, description, status, created_at) VALUES ('Lambda Test', 'Testing pg8000', 'PENDING', NOW()) RETURNING id;" \
    > /tmp/test_task_id.txt 2>&1

TEST_TASK_ID=$(grep -o '[0-9]\+' /tmp/test_task_id.txt | head -1)

if [ ! -z "$TEST_TASK_ID" ]; then
    echo "Test task created with ID: $TEST_TASK_ID"
    
    # Invoke Lambda with this task
    TEST_PAYLOAD="{\"Records\":[{\"body\":\"{\\\"task_id\\\":$TEST_TASK_ID,\\\"title\\\":\\\"Lambda Test\\\",\\\"description\\\":\\\"Testing pg8000\\\"}\"}]}"
    
    docker-compose exec -T localstack awslocal lambda invoke \
        --function-name task-processor \
        --payload "$TEST_PAYLOAD" \
        /tmp/test-response.json > /dev/null 2>&1
    
    RESPONSE=$(docker-compose exec -T localstack cat /tmp/test-response.json 2>/dev/null)
    
    if echo "$RESPONSE" | grep -q "errorMessage"; then
        echo -e "${RED}✗ Lambda test failed${NC}"
        echo "Error: $RESPONSE"
    else
        echo -e "${GREEN}✓ Lambda executed successfully${NC}"
        
        # Check if task was updated
        sleep 2
        TASK_STATUS=$(docker-compose exec -T db psql -U postgres -d interview_db -t -c \
            "SELECT status FROM tasks WHERE id = $TEST_TASK_ID;" | tr -d ' \n\r')
        
        if [ "$TASK_STATUS" = "COMPLETED" ]; then
            echo -e "${GREEN}✓ Task status updated to COMPLETED!${NC}"
        else
            echo -e "${YELLOW}⚠ Task status: $TASK_STATUS${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⚠ Could not create test task${NC}"
fi
echo ""

# Step 8: Verify setup
echo -e "${BLUE}Step 8: Verifying setup...${NC}"

echo "Lambda function:"
docker-compose exec -T localstack awslocal lambda get-function-configuration \
    --function-name task-processor \
    --query '[FunctionName,Runtime,Handler,Timeout,MemorySize]' \
    --output table

echo ""
echo "Event source mapping:"
docker-compose exec -T localstack awslocal lambda list-event-source-mappings \
    --function-name task-processor \
    --query 'EventSourceMappings[*].[UUID,State,EventSourceArn]' \
    --output table

echo ""

# Cleanup
echo -e "${BLUE}Step 9: Cleaning up...${NC}"
rm -rf /tmp/lambda-package /tmp/lambda-fixed.zip /tmp/test_task_id.txt
echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Lambda function setup complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Summary:"
echo "  • Function Name: task-processor"
echo "  • Runtime: Python 3.9"
echo "  • Database Driver: pg8000 (pure Python)"
echo "  • Trigger: SQS (interview-queue)"
echo ""
echo "🧪 Test the complete flow:"
echo ""
echo "  1. Create a task:"
echo "     curl -X POST http://localhost:8000/tasks \\"
echo "       -H 'Content-Type: application/json' \\"
echo "       -d '{\"title\":\"Test Lambda\",\"description\":\"Testing automatic processing\"}'"
echo ""
echo "  2. Wait 10-15 seconds for Lambda to process"
echo ""
echo "  3. Check task status (should be COMPLETED):"
echo "     curl http://localhost:8000/tasks | python3 -m json.tool"
echo ""
echo "  4. Or run automated test:"
echo "     ./test_end_to_end.sh"
echo ""
