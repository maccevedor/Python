import boto3
import json
from app.config import get_settings

settings = get_settings()


class SQSClient:
    def __init__(self):
        self.client = boto3.client(
            'sqs',
            region_name=settings.aws_region,
            aws_access_key_id=settings.aws_access_key_id,
            aws_secret_access_key=settings.aws_secret_access_key,
            endpoint_url='http://localstack:4566' if settings.environment == 'development' else None
        )
        self.queue_url = settings.sqs_queue_url

    def send_message(self, message_body: dict):
        """Send a message to SQS queue"""
        try:
            response = self.client.send_message(
                QueueUrl=self.queue_url,
                MessageBody=json.dumps(message_body)
            )
            return response
        except Exception as e:
            print(f"Error sending message to SQS: {e}")
            raise

    def receive_messages(self, max_messages: int = 1, wait_time: int = 10):
        """Receive messages from SQS queue"""
        try:
            response = self.client.receive_message(
                QueueUrl=self.queue_url,
                MaxNumberOfMessages=max_messages,
                WaitTimeSeconds=wait_time
            )
            return response.get('Messages', [])
        except Exception as e:
            print(f"Error receiving messages from SQS: {e}")
            raise

    def delete_message(self, receipt_handle: str):
        """Delete a message from SQS queue"""
        try:
            self.client.delete_message(
                QueueUrl=self.queue_url,
                ReceiptHandle=receipt_handle
            )
        except Exception as e:
            print(f"Error deleting message from SQS: {e}")
            raise


def get_sqs_client():
    return SQSClient()
