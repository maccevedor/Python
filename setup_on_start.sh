#!/bin/bash

# This script runs after docker-compose up to set up Lambda automatically

echo "🔧 Post-startup Lambda setup..."
echo ""

# Wait for all services to be ready
echo "⏳ Waiting for services to be ready..."
sleep 10

# Check if containers are running
if ! docker-compose ps | grep -q "Up"; then
    echo "❌ Containers are not running. Please run: docker-compose up -d"
    exit 1
fi

# Run Lambda setup
echo "⚡ Setting up Lambda function..."
./setup_lambda_fixed.sh

echo ""
echo "✅ Startup setup complete!"
echo ""
echo "🌐 Services available:"
echo "   API:       http://localhost:8000"
echo "   Dashboard: http://localhost:8000/admin/dashboard"
echo "   Database:  localhost:5432"
echo ""
