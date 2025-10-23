#!/bin/bash

echo "🔍 Verifying AWS Credentials and SQS Setup..."
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if containers are running
echo -e "${BLUE}1. Checking containers...${NC}"
if docker-compose ps | grep -q "Up"; then
    echo -e "${GREEN}   ✓ Containers are running${NC}"
else
    echo -e "${RED}   ✗ Containers are not running${NC}"
    echo "   Run: docker-compose up -d"
    exit 1
fi
echo ""

# Check AWS credentials in LocalStack
echo -e "${BLUE}2. Checking AWS credentials in LocalStack...${NC}"
docker-compose exec -T localstack bash -c 'cat ~/.aws/credentials 2>/dev/null' > /dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}   ✓ AWS credentials file exists${NC}"
    docker-compose exec -T localstack bash -c 'cat ~/.aws/credentials'
else
    echo -e "${YELLOW}   ⚠ Credentials file not found (using environment variables)${NC}"
fi
echo ""

# Check AWS credentials in API container
echo -e "${BLUE}3. Checking AWS credentials in API container...${NC}"
docker-compose exec -T api bash -c 'cat ~/.aws/credentials 2>/dev/null' > /dev/null
if [ $? -eq 0 ]; then
    echo -e "${GREEN}   ✓ AWS credentials file exists${NC}"
else
    echo -e "${YELLOW}   ⚠ Credentials file not found (using environment variables)${NC}"
fi
echo ""

# List SQS queues
echo -e "${BLUE}4. Listing SQS queues...${NC}"
QUEUES=$(docker-compose exec -T localstack awslocal sqs list-queues 2>/dev/null)
if echo "$QUEUES" | grep -q "interview-queue"; then
    echo -e "${GREEN}   ✓ Queue 'interview-queue' exists${NC}"
    docker-compose exec -T localstack awslocal sqs get-queue-url --queue-name interview-queue
else
    echo -e "${YELLOW}   ⚠ Queue not found. Creating it...${NC}"
    docker-compose exec -T localstack awslocal sqs create-queue --queue-name interview-queue
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}   ✓ Queue created successfully${NC}"
    else
        echo -e "${RED}   ✗ Failed to create queue${NC}"
    fi
fi
echo ""

# Test sending a message
echo -e "${BLUE}5. Testing SQS message send/receive...${NC}"
SEND_RESULT=$(docker-compose exec -T localstack awslocal sqs send-message \
    --queue-url http://localhost:4566/000000000000/interview-queue \
    --message-body '{"task_id": 999, "title": "Test", "description": "Verification test"}' 2>&1)

if echo "$SEND_RESULT" | grep -q "MessageId"; then
    echo -e "${GREEN}   ✓ Message sent successfully${NC}"
    
    # Try to receive the message
    RECEIVE_RESULT=$(docker-compose exec -T localstack awslocal sqs receive-message \
        --queue-url http://localhost:4566/000000000000/interview-queue 2>&1)
    
    if echo "$RECEIVE_RESULT" | grep -q "Body"; then
        echo -e "${GREEN}   ✓ Message received successfully${NC}"
        
        # Extract receipt handle and delete message
        RECEIPT_HANDLE=$(echo "$RECEIVE_RESULT" | grep -o '"ReceiptHandle": "[^"]*"' | cut -d'"' -f4)
        if [ ! -z "$RECEIPT_HANDLE" ]; then
            docker-compose exec -T localstack awslocal sqs delete-message \
                --queue-url http://localhost:4566/000000000000/interview-queue \
                --receipt-handle "$RECEIPT_HANDLE" > /dev/null 2>&1
            echo -e "${GREEN}   ✓ Message deleted successfully${NC}"
        fi
    else
        echo -e "${YELLOW}   ⚠ Could not receive message${NC}"
    fi
else
    echo -e "${RED}   ✗ Failed to send message${NC}"
fi
echo ""

# Check API health
echo -e "${BLUE}6. Checking API health...${NC}"
API_HEALTH=$(curl -s http://localhost:8000/health 2>/dev/null)
if echo "$API_HEALTH" | grep -q "healthy"; then
    echo -e "${GREEN}   ✓ API is healthy${NC}"
    echo "   Response: $API_HEALTH"
else
    echo -e "${YELLOW}   ⚠ API is not responding yet${NC}"
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Verification Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📚 Next Steps:"
echo "   • API Docs: http://localhost:8000/docs"
echo "   • Create task: curl -X POST http://localhost:8000/tasks -H 'Content-Type: application/json' -d '{\"title\":\"Test\"}'"
echo "   • View logs: docker-compose logs -f"
echo ""
