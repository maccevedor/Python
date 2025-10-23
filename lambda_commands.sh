#!/bin/bash

# Lambda Management Commands for LocalStack
# Helper script to interact with Lambda functions

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "🔧 Lambda Management Commands"
echo "=============================="
echo ""

# Function to show menu
show_menu() {
    echo "Select an option:"
    echo "  1) List all Lambda functions"
    echo "  2) Get function details"
    echo "  3) List event source mappings (SQS triggers)"
    echo "  4) Invoke Lambda function manually"
    echo "  5) Create Lambda function"
    echo "  6) Delete Lambda function"
    echo "  7) Update Lambda function code"
    echo "  8) Get Lambda logs"
    echo "  9) Show all commands"
    echo "  0) Exit"
    echo ""
}

# 1. List Lambda functions
list_functions() {
    echo -e "${BLUE}Listing Lambda functions...${NC}"
    docker-compose exec localstack awslocal lambda list-functions \
        --query 'Functions[*].[FunctionName,Runtime,Handler,LastModified]' \
        --output table
    echo ""
}

# 2. Get function details
get_function_details() {
    echo -e "${YELLOW}Enter function name (e.g., task-processor):${NC}"
    read FUNCTION_NAME
    
    echo -e "${BLUE}Getting details for $FUNCTION_NAME...${NC}"
    docker-compose exec localstack awslocal lambda get-function \
        --function-name "$FUNCTION_NAME" | python3 -m json.tool
    echo ""
}

# 3. List event source mappings
list_event_mappings() {
    echo -e "${BLUE}Listing event source mappings (SQS → Lambda)...${NC}"
    docker-compose exec localstack awslocal lambda list-event-source-mappings \
        --query 'EventSourceMappings[*].[UUID,FunctionArn,EventSourceArn,State]' \
        --output table
    echo ""
}

# 4. Invoke Lambda function
invoke_function() {
    echo -e "${YELLOW}Enter function name:${NC}"
    read FUNCTION_NAME
    
    echo -e "${YELLOW}Enter task ID to process:${NC}"
    read TASK_ID
    
    echo -e "${BLUE}Invoking Lambda function...${NC}"
    
    PAYLOAD="{\"Records\":[{\"body\":\"{\\\"task_id\\\":$TASK_ID,\\\"title\\\":\\\"Test Task\\\"}\"}]}"
    
    docker-compose exec localstack awslocal lambda invoke \
        --function-name "$FUNCTION_NAME" \
        --payload "$PAYLOAD" \
        /tmp/response.json
    
    echo ""
    echo -e "${GREEN}Response:${NC}"
    docker-compose exec localstack cat /tmp/response.json | python3 -m json.tool
    echo ""
}

# 5. Create Lambda function
create_function() {
    echo -e "${BLUE}Creating Lambda function...${NC}"
    
    # Check if lambda code exists
    if [ ! -f "lambda/lambda_function.py" ]; then
        echo -e "${RED}Error: lambda/lambda_function.py not found${NC}"
        return
    fi
    
    # Zip the lambda code
    echo "Packaging Lambda code..."
    cd lambda && zip -r ../lambda.zip . && cd ..
    
    # Create function
    docker-compose exec localstack awslocal lambda create-function \
        --function-name task-processor \
        --runtime python3.9 \
        --handler lambda_function.lambda_handler \
        --role arn:aws:iam::000000000000:role/lambda-role \
        --zip-file fileb://lambda.zip
    
    echo -e "${GREEN}✓ Lambda function created${NC}"
    echo ""
}

# 6. Delete Lambda function
delete_function() {
    echo -e "${YELLOW}Enter function name to delete:${NC}"
    read FUNCTION_NAME
    
    echo -e "${RED}Are you sure you want to delete $FUNCTION_NAME? (yes/no)${NC}"
    read CONFIRM
    
    if [ "$CONFIRM" = "yes" ]; then
        docker-compose exec localstack awslocal lambda delete-function \
            --function-name "$FUNCTION_NAME"
        echo -e "${GREEN}✓ Function deleted${NC}"
    else
        echo "Cancelled"
    fi
    echo ""
}

# 7. Update Lambda function code
update_function() {
    echo -e "${YELLOW}Enter function name:${NC}"
    read FUNCTION_NAME
    
    echo -e "${BLUE}Updating Lambda function code...${NC}"
    
    # Zip the lambda code
    cd lambda && zip -r ../lambda.zip . && cd ..
    
    docker-compose exec localstack awslocal lambda update-function-code \
        --function-name "$FUNCTION_NAME" \
        --zip-file fileb://lambda.zip
    
    echo -e "${GREEN}✓ Function code updated${NC}"
    echo ""
}

# 8. Get Lambda logs
get_logs() {
    echo -e "${YELLOW}Enter function name:${NC}"
    read FUNCTION_NAME
    
    echo -e "${BLUE}Getting logs for $FUNCTION_NAME...${NC}"
    
    # Get log group name
    LOG_GROUP="/aws/lambda/$FUNCTION_NAME"
    
    docker-compose exec localstack awslocal logs describe-log-streams \
        --log-group-name "$LOG_GROUP" \
        --order-by LastEventTime \
        --descending \
        --max-items 1
    echo ""
}

# 9. Show all commands
show_all_commands() {
    echo -e "${BLUE}All Lambda Commands:${NC}"
    echo ""
    echo "# List functions"
    echo "docker-compose exec localstack awslocal lambda list-functions"
    echo ""
    echo "# Get function details"
    echo "docker-compose exec localstack awslocal lambda get-function --function-name FUNCTION_NAME"
    echo ""
    echo "# List event source mappings"
    echo "docker-compose exec localstack awslocal lambda list-event-source-mappings"
    echo ""
    echo "# Invoke function"
    echo "docker-compose exec localstack awslocal lambda invoke --function-name FUNCTION_NAME --payload '{...}' response.json"
    echo ""
    echo "# Create function"
    echo "docker-compose exec localstack awslocal lambda create-function --function-name NAME --runtime python3.9 --handler lambda_function.lambda_handler --role ROLE --zip-file fileb://lambda.zip"
    echo ""
    echo "# Update function code"
    echo "docker-compose exec localstack awslocal lambda update-function-code --function-name NAME --zip-file fileb://lambda.zip"
    echo ""
    echo "# Delete function"
    echo "docker-compose exec localstack awslocal lambda delete-function --function-name NAME"
    echo ""
    echo "# Get function configuration"
    echo "docker-compose exec localstack awslocal lambda get-function-configuration --function-name NAME"
    echo ""
    echo "# List aliases"
    echo "docker-compose exec localstack awslocal lambda list-aliases --function-name NAME"
    echo ""
    echo "# List versions"
    echo "docker-compose exec localstack awslocal lambda list-versions-by-function --function-name NAME"
    echo ""
}

# Main menu loop
if [ $# -eq 0 ]; then
    while true; do
        show_menu
        read -p "Enter option: " option
        
        case $option in
            1) list_functions ;;
            2) get_function_details ;;
            3) list_event_mappings ;;
            4) invoke_function ;;
            5) create_function ;;
            6) delete_function ;;
            7) update_function ;;
            8) get_logs ;;
            9) show_all_commands ;;
            0) echo "Goodbye!"; exit 0 ;;
            *) echo -e "${RED}Invalid option${NC}" ;;
        esac
    done
else
    # Direct command execution
    case $1 in
        list) list_functions ;;
        details) get_function_details ;;
        mappings) list_event_mappings ;;
        invoke) invoke_function ;;
        create) create_function ;;
        delete) delete_function ;;
        update) update_function ;;
        logs) get_logs ;;
        commands) show_all_commands ;;
        *) echo "Usage: $0 [list|details|mappings|invoke|create|delete|update|logs|commands]" ;;
    esac
fi
