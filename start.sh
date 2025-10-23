#!/bin/bash

# Complete startup script for the interview project
# This script starts all services and sets up Lambda automatically

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Starting Interview Project"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Step 1: Start Docker containers
echo -e "${BLUE}Step 1: Starting Docker containers...${NC}"
docker-compose up -d

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to start containers${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Containers started${NC}"
echo ""

# Step 2: Wait for services to be healthy
echo -e "${BLUE}Step 2: Waiting for services to be healthy...${NC}"

# Wait for database
echo "  Waiting for PostgreSQL..."
for i in {1..30}; do
    if docker-compose exec -T db pg_isready -U postgres > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ PostgreSQL is ready${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "  ${RED}✗ PostgreSQL timeout${NC}"
        exit 1
    fi
    sleep 1
done

# Wait for LocalStack
echo "  Waiting for LocalStack..."
for i in {1..30}; do
    if curl -s http://localhost:4566/_localstack/health > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ LocalStack is ready${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "  ${RED}✗ LocalStack timeout${NC}"
        exit 1
    fi
    sleep 1
done

# Wait for API
echo "  Waiting for FastAPI..."
for i in {1..30}; do
    if curl -s http://localhost:8000/health > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ FastAPI is ready${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "  ${RED}✗ FastAPI timeout${NC}"
        exit 1
    fi
    sleep 1
done

echo ""

# Step 3: Setup Lambda function
echo -e "${BLUE}Step 3: Setting up Lambda function...${NC}"
./setup_lambda_fixed.sh > /tmp/lambda_setup.log 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Lambda function deployed${NC}"
else
    echo -e "${YELLOW}⚠ Lambda setup had issues (check /tmp/lambda_setup.log)${NC}"
fi

echo ""

# Step 4: Verify everything is working
echo -e "${BLUE}Step 4: Verifying setup...${NC}"

# Check Lambda
LAMBDA_COUNT=$(docker-compose exec -T localstack awslocal lambda list-functions --query 'length(Functions)' --output text 2>/dev/null)
if [ "$LAMBDA_COUNT" -gt 0 ]; then
    echo -e "  ${GREEN}✓ Lambda function: task-processor${NC}"
else
    echo -e "  ${YELLOW}⚠ Lambda function not found${NC}"
fi

# Check SQS
QUEUE_EXISTS=$(docker-compose exec -T localstack awslocal sqs list-queues --query 'QueueUrls[0]' --output text 2>/dev/null)
if [ ! -z "$QUEUE_EXISTS" ] && [ "$QUEUE_EXISTS" != "None" ]; then
    echo -e "  ${GREEN}✓ SQS queue: interview-queue${NC}"
else
    echo -e "  ${YELLOW}⚠ SQS queue not found${NC}"
fi

# Check API
API_STATUS=$(curl -s http://localhost:8000/health | grep -o '"status":"healthy"')
if [ ! -z "$API_STATUS" ]; then
    echo -e "  ${GREEN}✓ API: healthy${NC}"
else
    echo -e "  ${YELLOW}⚠ API: not responding${NC}"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ Startup complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🌐 Services:"
echo "   API:            http://localhost:8000"
echo "   Admin Dashboard: http://localhost:8000/admin/dashboard"
echo "   API Docs:       http://localhost:8000/docs"
echo "   Database:       localhost:5432"
echo ""
echo "🧪 Test the system:"
echo "   curl -X POST http://localhost:8000/tasks \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{\"title\":\"Test Task\",\"description\":\"Testing\"}'"
echo ""
echo "📊 View logs:"
echo "   docker-compose logs -f api"
echo "   docker-compose logs -f localstack"
echo ""
echo "🛑 Stop services:"
echo "   docker-compose down"
echo ""
