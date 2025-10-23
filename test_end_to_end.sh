#!/bin/bash

echo "🧪 Testing Complete Flow: API → SQS → Lambda → Database"
echo "=========================================================="
echo ""

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Step 1: Create task
echo -e "${BLUE}📝 Step 1: Creating task via API...${NC}"
RESPONSE=$(curl -s -X POST http://localhost:8000/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Complete Flow Test","description":"Testing end-to-end process"}')

TASK_ID=$(echo $RESPONSE | grep -o '"id":[0-9]*' | grep -o '[0-9]*')
echo -e "${GREEN}✅ Task created with ID: $TASK_ID${NC}"
echo "Response:"
echo "$RESPONSE" | python3 -m json.tool
echo ""

# Step 2: Check initial status
echo -e "${BLUE}📊 Step 2: Checking initial task status...${NC}"
echo "Status should be 'pending'"
curl -s http://localhost:8000/tasks/$TASK_ID | python3 -m json.tool
echo ""

# Step 3: Check SQS queue
echo -e "${BLUE}📬 Step 3: Checking SQS queue for message...${NC}"
SQS_MSG=$(docker-compose exec -T localstack awslocal sqs receive-message \
  --queue-url http://localhost:4566/000000000000/interview-queue \
  --max-number-of-messages 1 2>/dev/null)

if echo "$SQS_MSG" | grep -q "MessageId"; then
    echo -e "${GREEN}✅ Message found in queue!${NC}"
    echo "Message details:"
    echo "$SQS_MSG" | python3 -m json.tool
    
    # Extract and show just the body
    BODY=$(echo "$SQS_MSG" | grep -o '"Body": "[^"]*"' | cut -d'"' -f4)
    echo ""
    echo "Message body (what Lambda will receive):"
    echo "$BODY"
else
    echo -e "${YELLOW}⚠️  Queue is empty (Lambda may have already processed it)${NC}"
fi
echo ""

# Step 4: Wait for Lambda
echo -e "${BLUE}⏳ Step 4: Waiting for Lambda to process...${NC}"
echo "Lambda polls SQS every few seconds. Waiting 10 seconds..."
for i in {10..1}; do
    echo -n "$i... "
    sleep 1
done
echo ""
echo ""

# Step 5: Check final status
echo -e "${BLUE}🎯 Step 5: Checking final task status...${NC}"
echo "Status should now be 'completed' with a result"
FINAL=$(curl -s http://localhost:8000/tasks/$TASK_ID)
echo "$FINAL" | python3 -m json.tool
echo ""

# Step 6: Verify queue is empty
echo -e "${BLUE}📭 Step 6: Verifying queue is empty...${NC}"
QUEUE_COUNT=$(docker-compose exec -T localstack awslocal sqs get-queue-attributes \
  --queue-url http://localhost:4566/000000000000/interview-queue \
  --attribute-names ApproximateNumberOfMessages \
  --query 'Attributes.ApproximateNumberOfMessages' \
  --output text 2>/dev/null | tr -d '\r')

echo "Messages in queue: $QUEUE_COUNT"
if [ "$QUEUE_COUNT" = "0" ]; then
    echo -e "${GREEN}✅ Queue is empty (message was processed and deleted)${NC}"
else
    echo -e "${YELLOW}⚠️  Queue still has messages${NC}"
fi
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${BLUE}📋 Test Summary${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if successful
if echo "$FINAL" | grep -q '"status": "completed"'; then
    echo -e "${GREEN}🎉 SUCCESS! Task was processed by Lambda${NC}"
    echo ""
    echo "Complete flow executed:"
    echo "  1. ✅ API created task (status: pending)"
    echo "     📍 Code: app/main.py lines 39-75"
    echo ""
    echo "  2. ✅ API sent message to SQS"
    echo "     📍 Code: app/sqs_client.py lines 19-29"
    echo ""
    echo "  3. ✅ Lambda received message from SQS"
    echo "     📍 Code: lambda/lambda_function.py lines 31-117"
    echo ""
    echo "  4. ✅ Lambda processed task"
    echo "     📍 Code: lambda/lambda_function.py lines 17-28"
    echo ""
    echo "  5. ✅ Lambda updated status to completed"
    echo "     📍 Code: lambda/lambda_function.py lines 66-73"
    echo ""
    echo "  6. ✅ Lambda deleted message from queue"
    echo "     (Automatic when Lambda returns success)"
    echo ""
elif echo "$FINAL" | grep -q '"status": "processing"'; then
    echo -e "${YELLOW}⚠️  Task is still processing${NC}"
    echo "Lambda may still be working. Wait a bit longer and check:"
    echo "  curl http://localhost:8000/tasks/$TASK_ID"
    echo ""
elif echo "$FINAL" | grep -q '"status": "failed"'; then
    echo -e "${RED}❌ Task failed during processing${NC}"
    echo "Check the result field for error details"
    echo ""
else
    echo -e "${YELLOW}⚠️  Task status: $(echo $FINAL | grep -o '"status": "[^"]*"')${NC}"
    echo ""
    echo "Troubleshooting steps:"
    echo ""
    echo "1. Check if Lambda function exists:"
    echo "   docker-compose exec localstack awslocal lambda list-functions"
    echo ""
    echo "2. Check if SQS trigger is connected:"
    echo "   docker-compose exec localstack awslocal lambda list-event-source-mappings"
    echo ""
    echo "3. Check LocalStack logs:"
    echo "   docker-compose logs localstack | tail -50"
    echo ""
    echo "4. Recreate Lambda function:"
    echo "   ./setup_lambda.sh"
    echo ""
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📚 For detailed code locations, see: COMPLETE_TEST_GUIDE.md"
echo ""
