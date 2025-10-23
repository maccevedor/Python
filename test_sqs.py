#!/usr/bin/env python3
"""
Test script to verify SQS queue is working with LocalStack
"""
import boto3
import json
from datetime import datetime

# Configure SQS client for LocalStack
sqs = boto3.client(
    'sqs',
    endpoint_url='http://localhost:4566',  # Use 'localstack:4566' from inside containers
    region_name='us-east-1',
    aws_access_key_id='test',
    aws_secret_access_key='test'
)

def test_queue_operations():
    """Test basic SQS operations"""
    
    print("🔍 Testing SQS Queue Operations...\n")
    
    # 1. List queues
    print("1. Listing queues...")
    try:
        response = sqs.list_queues()
        queues = response.get('QueueUrls', [])
        print(f"   ✓ Found {len(queues)} queue(s)")
        for queue in queues:
            print(f"     - {queue}")
    except Exception as e:
        print(f"   ✗ Error: {e}")
        return
    
    # 2. Get queue URL
    print("\n2. Getting queue URL...")
    try:
        response = sqs.get_queue_url(QueueName='interview-queue')
        queue_url = response['QueueUrl']
        print(f"   ✓ Queue URL: {queue_url}")
    except Exception as e:
        print(f"   ✗ Error: {e}")
        print("   ℹ Queue might not exist. Creating it...")
        try:
            response = sqs.create_queue(QueueName='interview-queue')
            queue_url = response['QueueUrl']
            print(f"   ✓ Queue created: {queue_url}")
        except Exception as create_error:
            print(f"   ✗ Failed to create queue: {create_error}")
            return
    
    # 3. Send message
    print("\n3. Sending test message...")
    try:
        message_body = {
            'task_id': 999,
            'title': 'Test Task',
            'description': f'Test message sent at {datetime.now().isoformat()}',
            'test': True
        }
        response = sqs.send_message(
            QueueUrl=queue_url,
            MessageBody=json.dumps(message_body)
        )
        message_id = response['MessageId']
        print(f"   ✓ Message sent successfully")
        print(f"     Message ID: {message_id}")
    except Exception as e:
        print(f"   ✗ Error: {e}")
        return
    
    # 4. Receive message
    print("\n4. Receiving message...")
    try:
        response = sqs.receive_message(
            QueueUrl=queue_url,
            MaxNumberOfMessages=1,
            WaitTimeSeconds=5
        )
        messages = response.get('Messages', [])
        if messages:
            message = messages[0]
            print(f"   ✓ Message received")
            print(f"     Body: {message['Body']}")
            receipt_handle = message['ReceiptHandle']
            
            # 5. Delete message
            print("\n5. Deleting message...")
            sqs.delete_message(
                QueueUrl=queue_url,
                ReceiptHandle=receipt_handle
            )
            print(f"   ✓ Message deleted successfully")
        else:
            print(f"   ⚠ No messages in queue")
    except Exception as e:
        print(f"   ✗ Error: {e}")
        return
    
    # 6. Get queue attributes
    print("\n6. Getting queue attributes...")
    try:
        response = sqs.get_queue_attributes(
            QueueUrl=queue_url,
            AttributeNames=['All']
        )
        attributes = response['Attributes']
        print(f"   ✓ Queue attributes:")
        print(f"     - Messages Available: {attributes.get('ApproximateNumberOfMessages', 0)}")
        print(f"     - Messages In Flight: {attributes.get('ApproximateNumberOfMessagesNotVisible', 0)}")
        print(f"     - Visibility Timeout: {attributes.get('VisibilityTimeout', 'N/A')}s")
    except Exception as e:
        print(f"   ✗ Error: {e}")
    
    print("\n✅ All tests completed!")

if __name__ == '__main__':
    test_queue_operations()
