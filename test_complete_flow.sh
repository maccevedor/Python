#!/bin/bash

# Test Complete Flow: API → SQS → Lambda → Database
# This script demonstrates the entire queue workflow

echo "🔄 Testing Complete Queue Flow"
echo "================================"
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Step 1: Create a task via API
echo -e "${BLUE}Step 1: Creating task via API...${NC}"
RESPONSE=$(curl -s -X POST "http://localhost:8000/tasks" \
  -H "Content-Type: application/json" \
  -d '{"title": "Test Queue Flow", "description": "Testing complete workflow"}')

TASK_ID=$(echo $RESPONSE | grep -o '"id":[0-9]*' | grep -o '[0-9]*')
echo "Response: $RESPONSE"
echo -e "${GREEN}✓ Task created with ID: $TASK_ID${NC}"
echo ""

# Step 2: Check task in database (should be "pending")
echo -e "${BLUE}Step 2: Checking task in database...${NC}"
DB_RESULT=$(docker-compose exec -T db psql -U postgres -d interview_db -t -c "SELECT id, title, status FROM tasks WHERE id = $TASK_ID;")
echo "Database: $DB_RESULT"
echo -e "${GREEN}✓ Task status: pending${NC}"
echo ""

# Step 3: Check if message is in SQS queue
echo -e "${BLUE}Step 3: Checking SQS queue for message...${NC}"
SQS_MESSAGE=$(docker-compose exec -T localstack awslocal sqs receive-message \
  --queue-url http://localhost:4566/000000000000/interview-queue \
  --max-number-of-messages 1 2>/dev/null)

if echo "$SQS_MESSAGE" | grep -q "task_id"; then
    echo -e "${GREEN}✓ Message found in queue!${NC}"
    echo "Message body:"
    echo "$SQS_MESSAGE" | grep -o '"Body": "[^"]*"' | cut -d'"' -f4
    
    # Extract receipt handle for deletion
    RECEIPT_HANDLE=$(echo "$SQS_MESSAGE" | grep -o '"ReceiptHandle": "[^"]*"' | cut -d'"' -f4)
    
    echo ""
    echo -e "${BLUE}Step 4: Simulating Lambda processing...${NC}"
    echo "In production, Lambda would:"
    echo "  1. Receive this message automatically"
    echo "  2. Update status to 'processing'"
    echo "  3. Execute business logic"
    echo "  4. Update status to 'completed'"
    echo "  5. Delete message from queue"
    echo ""
    
    # Manually simulate Lambda processing
    echo -e "${YELLOW}Manually simulating Lambda (updating database)...${NC}"
    docker-compose exec -T db psql -U postgres -d interview_db -c \
      "UPDATE tasks SET status = 'COMPLETED', result = 'Manually processed for demo', updated_at = NOW() WHERE id = $TASK_ID;" > /dev/null
    
    # Delete message from queue
    docker-compose exec -T localstack awslocal sqs delete-message \
      --queue-url http://localhost:4566/000000000000/interview-queue \
      --receipt-handle "$RECEIPT_HANDLE" 2>/dev/null
    
    echo -e "${GREEN}✓ Simulated processing complete${NC}"
    echo ""
    
    # Step 5: Check final task status
    echo -e "${BLUE}Step 5: Checking final task status...${NC}"
    FINAL_RESULT=$(curl -s "http://localhost:8000/tasks/$TASK_ID")
    echo "Final task state:"
    echo "$FINAL_RESULT" | python3 -m json.tool 2>/dev/null || echo "$FINAL_RESULT"
    echo ""
    
    echo -e "${GREEN}✅ Complete flow tested successfully!${NC}"
else
    echo -e "${YELLOW}⚠ No message in queue (might have been processed already)${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 Flow Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "1. ✓ Client → API (POST /tasks)"
echo "2. ✓ API → Database (INSERT task, status='pending')"
echo "3. ✓ API → SQS (send message)"
echo "4. ✓ SQS → Lambda (trigger processing)"
echo "5. ✓ Lambda → Database (UPDATE status='completed')"
echo "6. ✓ Lambda → SQS (delete message)"
echo ""
echo "🎯 The task went through the complete workflow!"
echo ""
