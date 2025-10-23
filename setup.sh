#!/bin/bash

# Interview Project Setup Script
# This script sets up the entire project environment

set -e

echo "🚀 Setting up Interview Project..."
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker is not running. Please start Docker Desktop and try again."
    exit 1
fi

echo -e "${GREEN}✓${NC} Docker is running"

# Check if docker-compose is available
if ! command -v docker-compose &> /dev/null; then
    echo "❌ docker-compose is not installed. Please install it and try again."
    exit 1
fi

echo -e "${GREEN}✓${NC} docker-compose is available"

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo -e "${BLUE}Creating .env file...${NC}"
    cp .env.example .env
    echo -e "${GREEN}✓${NC} .env file created"
else
    echo -e "${YELLOW}⚠${NC}  .env file already exists, skipping..."
fi

# Make localstack init script executable
echo -e "${BLUE}Setting up LocalStack...${NC}"
chmod +x localstack/init-aws.sh
echo -e "${GREEN}✓${NC} LocalStack script is executable"

# Build Docker images
echo -e "${BLUE}Building Docker images...${NC}"
docker-compose build
echo -e "${GREEN}✓${NC} Docker images built"

# Start services
echo -e "${BLUE}Starting services...${NC}"
docker-compose up -d
echo -e "${GREEN}✓${NC} Services started"

# Wait for services to be healthy
echo -e "${BLUE}Waiting for services to be ready...${NC}"
sleep 10

# Check service health
echo -e "${BLUE}Checking service health...${NC}"

# Check API
if curl -s http://localhost:8000/health > /dev/null; then
    echo -e "${GREEN}✓${NC} API is healthy"
else
    echo -e "${YELLOW}⚠${NC}  API is not responding yet (this is normal, it may need more time)"
fi

# Check database
if docker-compose exec -T db pg_isready -U postgres > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Database is ready"
else
    echo -e "${YELLOW}⚠${NC}  Database is not ready yet"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✨ Setup Complete!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📚 Access Points:"
echo "   • API Documentation: http://localhost:8000/docs"
echo "   • API Health Check:  http://localhost:8000/health"
echo "   • PostgreSQL:        localhost:5432"
echo "   • LocalStack:        http://localhost:4566"
echo ""
echo "🔧 Useful Commands:"
echo "   • View logs:         docker-compose logs -f"
echo "   • Stop services:     docker-compose down"
echo "   • Restart services:  docker-compose restart"
echo "   • Run tests:         docker-compose exec api pytest"
echo "   • Database shell:    docker-compose exec db psql -U postgres -d interview_db"
echo ""
echo "📖 Documentation:"
echo "   • Quick Start:       cat QUICKSTART.md"
echo "   • Full README:       cat README.md"
echo "   • Interview Q&A:     cat INTERVIEW_QUESTIONS.md"
echo ""
echo "🎯 Next Steps:"
echo "   1. Open http://localhost:8000/docs in your browser"
echo "   2. Try creating a task using the API"
echo "   3. Review the interview questions"
echo "   4. Explore the codebase"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Happy Coding! 🚀"
echo ""
