#!/bin/bash

echo "🚀 Initializing LocalStack resources..."

# Wait for LocalStack to be ready
echo "Waiting for LocalStack to be ready..."
sleep 5

# Create SQS Queue
echo "📬 Creating SQS Queue..."
awslocal sqs create-queue --queue-name interview-queue

# Get queue URL and ARN
QUEUE_URL=$(awslocal sqs get-queue-url --queue-name interview-queue --query 'QueueUrl' --output text)
QUEUE_ARN=$(awslocal sqs get-queue-attributes --queue-url "$QUEUE_URL" --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)

echo "✓ SQS Queue created: $QUEUE_URL"
echo "✓ Queue ARN: $QUEUE_ARN"

# Deploy Lambda function
echo "⚡ Deploying Lambda function..."

# Check if Lambda package exists
if [ ! -f "/tmp/lambda-init.zip" ]; then
    echo "Lambda package not found, will be deployed later via setup_lambda_fixed.sh"
else
    # Create Lambda function
    awslocal lambda create-function \
        --function-name task-processor \
        --runtime python3.9 \
        --handler lambda_function.lambda_handler \
        --role arn:aws:iam::000000000000:role/lambda-role \
        --zip-file fileb:///tmp/lambda-init.zip \
        --timeout 60 \
        --memory-size 256 \
        --environment Variables="{DB_HOST=db,DB_NAME=interview_db,DB_USER=postgres,DB_PASSWORD=postgres,DB_PORT=5432}" \
        2>/dev/null

    if [ $? -eq 0 ]; then
        echo "✓ Lambda function created"
        
        # Create event source mapping (SQS trigger)
        awslocal lambda create-event-source-mapping \
            --function-name task-processor \
            --event-source-arn "$QUEUE_ARN" \
            --batch-size 10 \
            --enabled \
            2>/dev/null
        
        echo "✓ SQS trigger connected to Lambda"
    else
        echo "⚠ Lambda function creation skipped (may already exist or package not ready)"
    fi
fi

echo "✅ LocalStack initialization complete!"
echo ""
echo "📝 Note: To deploy/update Lambda function, run: ./setup_lambda_fixed.sh"
