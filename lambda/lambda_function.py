import json
import os
import psycopg2
from datetime import datetime


def get_db_connection():
    """Create database connection"""
    return psycopg2.connect(
        host=os.environ.get('DB_HOST', 'db'),
        database=os.environ.get('DB_NAME', 'interview_db'),
        user=os.environ.get('DB_USER', 'postgres'),
        password=os.environ.get('DB_PASSWORD', 'postgres')
    )


def process_task(task_id, title, description):
    """
    Process the task - This is where you would implement your business logic
    For this example, we'll just simulate processing and update the task status
    """
    # Simulate some processing
    result = f"Processed task '{title}' at {datetime.now().isoformat()}"
    
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
    
    for record in event['Records']:
        try:
            # Parse SQS message
            message_body = json.loads(record['body'])
            task_id = message_body.get('task_id')
            title = message_body.get('title')
            description = message_body.get('description')
            
            print(f"Processing task {task_id}: {title}")
            
            # Connect to database
            conn = get_db_connection()
            cursor = conn.cursor()
            
            # Update task status to PROCESSING
            cursor.execute(
                "UPDATE tasks SET status = %s, updated_at = %s WHERE id = %s",
                ('processing', datetime.now(), task_id)
            )
            conn.commit()
            
            # Process the task
            result = process_task(task_id, title, description)
            
            # Update task status to COMPLETED
            cursor.execute(
                """
                UPDATE tasks 
                SET status = %s, result = %s, updated_at = %s 
                WHERE id = %s
                """,
                ('completed', result, datetime.now(), task_id)
            )
            conn.commit()
            
            cursor.close()
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
                cursor = conn.cursor()
                cursor.execute(
                    """
                    UPDATE tasks 
                    SET status = %s, result = %s, updated_at = %s 
                    WHERE id = %s
                    """,
                    ('failed', f"Error: {error_msg}", datetime.now(), task_id)
                )
                conn.commit()
                cursor.close()
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
