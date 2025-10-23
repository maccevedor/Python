#!/bin/bash

# Restart API and Test Dashboard

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "🔄 Restarting API container..."
docker-compose restart api

echo ""
echo -e "${BLUE}Waiting for API to start...${NC}"
sleep 5

echo ""
echo -e "${BLUE}Testing API health...${NC}"
curl -s http://localhost:8000/health | python3 -m json.tool

echo ""
echo ""
echo -e "${BLUE}Testing admin status endpoint...${NC}"
curl -s http://localhost:8000/admin/status | python3 -m json.tool | head -30

echo ""
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✅ API restarted successfully!${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "🌐 Open in your browser:"
echo "   Admin Dashboard: http://localhost:8000/admin/dashboard"
echo "   API Status:      http://localhost:8000/admin/status"
echo "   API Root:        http://localhost:8000/"
echo ""
