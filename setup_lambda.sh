#!/bin/bash

# Setup Lambda Function in LocalStack
# This script creates the Lambda function and connects it to SQS

set -e  # Exit on error

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "🚀 Setting up Lambda Function in LocalStack"
echo "==========================================="
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

# Step 2: Skip local dependency installation (Lambda will use container's Python)
echo -e "${BLUE}Step 2: Preparing Lambda package...${NC}"
echo -e "${YELLOW}Note: Dependencies will be available in Lambda runtime${NC}"
echo -e "${GREEN}✓ Ready to package${NC}"
echo ""

# Step 3: Package Lambda function
echo -e "${BLUE}Step 3: Packaging Lambda function...${NC}"
cd lambda
zip lambda.zip lambda_function.py > /dev/null 2>&1
mv lambda.zip ..
cd ..
echo -e "${GREEN}✓ Lambda function packaged (lambda_function.py)${NC}"
echo ""

# Step 4: Copy zip file to LocalStack container
echo -e "${BLUE}Step 4: Copying package to LocalStack...${NC}"
docker cp lambda.zip interview_localstack:/tmp/lambda.zip
echo -e "${GREEN}✓ Package copied${NC}"
echo ""

# Step 5: Create Lambda function
echo -e "${BLUE}Step 5: Creating Lambda function...${NC}"

# Check if function already exists
EXISTING=$(docker-compose exec -T localstack awslocal lambda list-functions --query 'Functions[?FunctionName==`task-processor`].FunctionName' --output text 2>/dev/null || echo "")

if [ ! -z "$EXISTING" ]; then
    echo -e "${YELLOW}Function 'task-processor' already exists. Updating...${NC}"
    docker-compose exec -T localstack awslocal lambda update-function-code \
        --function-name task-processor \
        --zip-file fileb:///tmp/lambda.zip > /dev/null
    echo -e "${GREEN}✓ Lambda function updated${NC}"
else
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

# Step 6: Create event source mapping (SQS → Lambda)
echo -e "${BLUE}Step 6: Connecting SQS to Lambda...${NC}"

# Get queue ARN
QUEUE_ARN=$(docker-compose exec -T localstack awslocal sqs get-queue-attributes \
    --queue-url http://localhost:4566/000000000000/interview-queue \
    --attribute-names QueueArn \
    --query 'Attributes.QueueArn' \
    --output text 2>/dev/null | tr -d '\r')

if [ -z "$QUEUE_ARN" ]; then
    echo -e "${RED}Error: Queue not found. Creating queue...${NC}"
    docker-compose exec -T localstack awslocal sqs create-queue --queue-name interview-queue > /dev/null
    QUEUE_ARN=$(docker-compose exec -T localstack awslocal sqs get-queue-attributes \
        --queue-url http://localhost:4566/000000000000/interview-queue \
        --attribute-names QueueArn \
        --query 'Attributes.QueueArn' \
        --output text | tr -d '\r')
fi

echo "Queue ARN: $QUEUE_ARN"

# Check if mapping already exists
EXISTING_MAPPING=$(docker-compose exec -T localstack awslocal lambda list-event-source-mappings \
    --function-name task-processor \
    --query 'EventSourceMappings[0].UUID' \
    --output text 2>/dev/null || echo "")

if [ ! -z "$EXISTING_MAPPING" ] && [ "$EXISTING_MAPPING" != "None" ]; then
    echo -e "${YELLOW}Event source mapping already exists${NC}"
else
    docker-compose exec -T localstack awslocal lambda create-event-source-mapping \
        --function-name task-processor \
        --event-source-arn "$QUEUE_ARN" \
        --batch-size 10 \
        --enabled > /dev/null
    echo -e "${GREEN}✓ Event source mapping created${NC}"
fi
echo ""

# Step 7: Verify setup
echo -e "${BLUE}Step 7: Verifying setup...${NC}"

# List functions
echo "Lambda functions:"
docker-compose exec -T localstack awslocal lambda list-functions \
    --query 'Functions[*].[FunctionName,Runtime,Handler]' \
    --output table

echo ""
echo "Event source mappings:"
docker-compose exec -T localstack awslocal lambda list-event-source-mappings \
    --function-name task-processor \
    --query 'EventSourceMappings[*].[UUID,State,EventSourceArn]' \
    --output table

echo ""

# Cleanup
echo -e "${BLUE}Step 8: Cleaning up...${NC}"
rm -f lambda.zip
rm -rf lambda/package
echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Lambda function setup complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Summary:"
echo "  • Function Name: task-processor"
echo "  • Runtime: Python 3.9"
echo "  • Handler: lambda_function.lambda_handler"
echo "  • Trigger: SQS (interview-queue)"
echo ""
echo "🧪 Test the function:"
echo "  1. Create a task via API:"
echo "     curl -X POST http://localhost:8000/tasks -H 'Content-Type: application/json' -d '{\"title\":\"Test\"}'"
echo ""
echo "  2. Or send message directly to SQS:"
echo "     docker-compose exec localstack awslocal sqs send-message \\"
echo "       --queue-url http://localhost:4566/000000000000/interview-queue \\"
echo "       --message-body '{\"task_id\":1,\"title\":\"Test\"}'"
echo ""
echo "  3. Check task status:"
echo "     curl http://localhost:8000/tasks/1"
echo ""
