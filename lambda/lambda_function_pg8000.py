import json
import os
from datetime import datetime

# Use pg8000 - pure Python PostgreSQL driver (no C extensions needed)
import pg8000.native

def get_db_connection():
    """Create a database connection using pg8000"""
    return pg8000.native.Connection(
        user=os.environ.get('DB_USER', 'postgres'),
        password=os.environ.get('DB_PASSWORD', 'postgres'),
        host=os.environ.get('DB_HOST', 'db'),
        database=os.environ.get('DB_NAME', 'interview_db'),
        port=int(os.environ.get('DB_PORT', '5432'))
    )

def process_task(task_id, title, description):
    """
    Process the task - This is where you would implement your business logic
    For this example, we'll just simulate processing and update the task status
    """
    # This is where you would add your custom business logic
    # Examples:
    # - Send email
    # - Generate report
    # - Call external API
    # - Process data
    # - Perform calculations
    
    result = f"Processed task ID {task_id}: '{title}' at {datetime.now().isoformat()}"
    
    if description:
        result += f" with description: {description}"
    
    return result

def lambda_handler(event, context):
    """
    AWS Lambda handler function
    Processes messages from SQS queue and updates task status in PostgreSQL
    """
    print(f"Received event: {json.dumps(event)}")
    
    processed_records = []
    failed_records = []
    
    # Process each record from SQS
    for record in event['Records']:
        try:
            # Parse the SQS message body
            message_body = json.loads(record['body'])
            task_id = message_body.get('task_id')
            title = message_body.get('title')
            description = message_body.get('description')
            
            print(f"Processing task {task_id}: {title}")
            
            # Connect to database using pg8000
            conn = get_db_connection()
            
            # Update task status to PROCESSING
            conn.run(
                "UPDATE tasks SET status = :status, updated_at = :updated_at WHERE id = :id",
                status='PROCESSING',
                updated_at=datetime.now(),
                id=task_id
            )
            
            # Process the task (your business logic here)
            result = process_task(task_id, title, description)
            
            # Update task status to COMPLETED with result
            conn.run(
                """
                UPDATE tasks 
                SET status = :status, result = :result, updated_at = :updated_at 
                WHERE id = :id
                """,
                status='COMPLETED',
                result=result,
                updated_at=datetime.now(),
                id=task_id
            )
            
            # Close connection
            conn.close()
            
            processed_records.append(task_id)
            print(f"Successfully processed task {task_id}")
            
        except Exception as e:
            error_msg = str(e)
            print(f"Error processing record: {error_msg}")
            failed_records.append({
                'task_id': task_id if 'task_id' in locals() else 'unknown',
                'error': error_msg
            })
            
            # Try to update task status to FAILED
            try:
                conn = get_db_connection()
                conn.run(
                    """
                    UPDATE tasks 
                    SET status = :status, result = :result, updated_at = :updated_at 
                    WHERE id = :id
                    """,
                    status='FAILED',
                    result=f"Error: {error_msg}",
                    updated_at=datetime.now(),
                    id=task_id
                )
                conn.close()
            except Exception as db_error:
                print(f"Failed to update task status: {db_error}")
    
    response = {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Processing complete',
            'processed': processed_records,
            'failed': failed_records
        })
    }
    
    return response
