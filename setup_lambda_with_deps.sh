#!/bin/bash

# Setup Lambda Function with Dependencies
# This script packages psycopg2-binary with the Lambda function

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "🚀 Setting up Lambda Function with Dependencies"
echo "==============================================="
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

# Step 2: Create temporary directory for dependencies
echo -e "${BLUE}Step 2: Installing psycopg2-binary...${NC}"
rm -rf /tmp/lambda-package
mkdir -p /tmp/lambda-package

# Install psycopg2-binary (works without PostgreSQL dev libraries)
pip3 install psycopg2-binary -t /tmp/lambda-package/ --quiet --no-cache-dir

echo -e "${GREEN}✓ psycopg2-binary installed${NC}"
echo ""

# Step 3: Package Lambda function with dependencies
echo -e "${BLUE}Step 3: Packaging Lambda function with dependencies...${NC}"

# Copy lambda function to package directory
cp lambda/lambda_function.py /tmp/lambda-package/

# Create zip file
cd /tmp/lambda-package
zip -r /tmp/lambda-with-deps.zip . > /dev/null 2>&1
cd - > /dev/null

echo -e "${GREEN}✓ Lambda function packaged with dependencies${NC}"
echo "Package size: $(du -h /tmp/lambda-with-deps.zip | cut -f1)"
echo ""

# Step 4: Copy zip file to LocalStack container
echo -e "${BLUE}Step 4: Copying package to LocalStack...${NC}"
docker cp /tmp/lambda-with-deps.zip interview_localstack:/tmp/lambda.zip
echo -e "${GREEN}✓ Package copied${NC}"
echo ""

# Step 5: Update or Create Lambda function
echo -e "${BLUE}Step 5: Updating Lambda function...${NC}"

# Check if function exists
EXISTING=$(docker-compose exec -T localstack awslocal lambda list-functions --query 'Functions[?FunctionName==`task-processor`].FunctionName' --output text 2>/dev/null || echo "")

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
        --environment Variables="{DB_HOST=db,DB_NAME=interview_db,DB_USER=postgres,DB_PASSWORD=postgres}" \
        > /dev/null
    echo -e "${GREEN}✓ Lambda function created${NC}"
fi
echo ""

# Step 6: Ensure event source mapping exists
echo -e "${BLUE}Step 6: Checking SQS trigger...${NC}"

# Get queue ARN
QUEUE_ARN=$(docker-compose exec -T localstack awslocal sqs get-queue-attributes \
    --queue-url http://localhost:4566/000000000000/interview-queue \
    --attribute-names QueueArn \
    --query 'Attributes.QueueArn' \
    --output text 2>/dev/null | tr -d '\r')

if [ -z "$QUEUE_ARN" ]; then
    echo -e "${RED}Error: Queue not found${NC}"
    exit 1
fi

# Check if mapping exists
EXISTING_MAPPING=$(docker-compose exec -T localstack awslocal lambda list-event-source-mappings \
    --function-name task-processor \
    --query 'EventSourceMappings[0].UUID' \
    --output text 2>/dev/null || echo "")

if [ ! -z "$EXISTING_MAPPING" ] && [ "$EXISTING_MAPPING" != "None" ]; then
    echo -e "${GREEN}✓ Event source mapping already exists${NC}"
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

# Test with a simple payload
TEST_PAYLOAD='{"Records":[{"body":"{\"task_id\":999,\"title\":\"Test\",\"description\":\"Test\"}"}]}'

docker-compose exec -T localstack awslocal lambda invoke \
    --function-name task-processor \
    --payload "$TEST_PAYLOAD" \
    /tmp/test-response.json > /dev/null 2>&1

RESPONSE=$(docker-compose exec -T localstack cat /tmp/test-response.json 2>/dev/null)

if echo "$RESPONSE" | grep -q "errorMessage"; then
    echo -e "${RED}✗ Lambda test failed${NC}"
    echo "Error: $RESPONSE"
    echo ""
    echo "This is expected if task_id 999 doesn't exist in database"
else
    echo -e "${GREEN}✓ Lambda function executed successfully${NC}"
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
rm -rf /tmp/lambda-package /tmp/lambda-with-deps.zip
echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Lambda function setup complete with dependencies!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Summary:"
echo "  • Function Name: task-processor"
echo "  • Runtime: Python 3.9"
echo "  • Dependencies: psycopg2-binary included"
echo "  • Trigger: SQS (interview-queue)"
echo ""
echo "🧪 Test the function:"
echo "  1. Create a task:"
echo "     curl -X POST http://localhost:8000/tasks -H 'Content-Type: application/json' -d '{\"title\":\"Test Lambda\"}'"
echo ""
echo "  2. Wait 10-15 seconds for Lambda to process"
echo ""
echo "  3. Check task status (should be 'completed'):"
echo "     curl http://localhost:8000/tasks/TASK_ID | python3 -m json.tool"
echo ""
echo "  4. Or run automated test:"
echo "     ./test_end_to_end.sh"
echo ""
