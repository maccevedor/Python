# AWS Credentials Setup Guide

## 📁 Repository Structure

The AWS credentials are now stored in the repository and shared with Docker containers:

```
python/
├── aws/
│   ├── credentials      # AWS access keys (test values)
│   ├── config          # AWS region and output format
│   └── README.md       # Documentation
├── docker-compose.yml  # Updated with volume mounts
└── .env                # Environment variables
```

## ✅ What Was Configured

### 1. AWS Credentials Files Created

**Location:** `./aws/credentials`
```ini
[default]
aws_access_key_id = test
aws_secret_access_key = test
```

**Location:** `./aws/config`
```ini
[default]
region = us-east-1
output = json
```

### 2. Docker Compose Updated

The credentials are mounted as read-only volumes in containers:

```yaml
api:
  volumes:
    - ./aws:/root/.aws:ro  # Read-only mount

localstack:
  environment:
    AWS_ACCESS_KEY_ID: test
    AWS_SECRET_ACCESS_KEY: test
    AWS_DEFAULT_REGION: us-east-1
  volumes:
    - ./aws:/root/.aws:ro  # Read-only mount
```

### 3. Environment Variables

Default values set in `docker-compose.yml`:

```yaml
AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID:-test}
AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY:-test}
SQS_QUEUE_URL: ${SQS_QUEUE_URL:-http://localstack:4566/000000000000/interview-queue}
```

## 🚀 Usage

### Automatic Setup

Everything is configured automatically when you run:

```bash
docker-compose up -d
```

### Verify Setup

Run the verification script:

```bash
./verify_setup.sh
```

This will check:
- ✅ Containers are running
- ✅ AWS credentials are mounted
- ✅ SQS queue exists
- ✅ Messages can be sent/received
- ✅ API is healthy

### Manual Verification

#### Check credentials in containers:

```bash
# In LocalStack
docker-compose exec localstack cat ~/.aws/credentials

# In API container
docker-compose exec api cat ~/.aws/credentials
```

#### Test AWS CLI:

```bash
# Enter LocalStack container
docker-compose exec localstack bash

# List queues (should work without errors)
awslocal sqs list-queues

# Create a queue
awslocal sqs create-queue --queue-name test-queue

# Send message
awslocal sqs send-message \
  --queue-url http://localhost:4566/000000000000/interview-queue \
  --message-body '{"test": "message"}'

# Receive message
awslocal sqs receive-message \
  --queue-url http://localhost:4566/000000000000/interview-queue
```

## 🔧 Troubleshooting

### Credentials not found

If you get "Unable to locate credentials" error:

```bash
# 1. Check if files exist
ls -la aws/

# 2. Restart containers
docker-compose down
docker-compose up -d

# 3. Verify mount
docker-compose exec localstack ls -la ~/.aws/
```

### Queue not created

```bash
# Manually create queue
docker-compose exec localstack awslocal sqs create-queue --queue-name interview-queue

# Verify
docker-compose exec localstack awslocal sqs list-queues
```

### Permission denied

```bash
# Fix file permissions
chmod 644 aws/credentials aws/config

# Restart containers
docker-compose restart
```

## 🔒 Security Notes

### ⚠️ Important

These credentials are **ONLY for local development** with LocalStack:

- ✅ **Safe to commit** - They are test values
- ✅ **No real AWS access** - LocalStack doesn't connect to AWS
- ❌ **Never use in production** - Use IAM roles or Secrets Manager
- ❌ **Never commit real credentials** - Always use environment variables

### Production Setup

For production AWS, use:

1. **IAM Roles** (Recommended)
   ```yaml
   # ECS Task Definition
   taskRoleArn: arn:aws:iam::123456789:role/MyTaskRole
   ```

2. **AWS Secrets Manager**
   ```python
   import boto3
   secrets = boto3.client('secretsmanager')
   secret = secrets.get_secret_value(SecretId='prod/api/credentials')
   ```

3. **Environment Variables**
   ```bash
   export AWS_ACCESS_KEY_ID=AKIA...
   export AWS_SECRET_ACCESS_KEY=...
   ```

4. **AWS Systems Manager**
   ```bash
   aws ssm get-parameter --name /prod/api/key --with-decryption
   ```

## 📊 File Permissions

The credentials are mounted as **read-only** (`:ro`) for security:

```yaml
volumes:
  - ./aws:/root/.aws:ro
```

This prevents containers from modifying the credential files.

## 🎯 Quick Reference

### Common Commands

```bash
# Verify setup
./verify_setup.sh

# Check credentials
docker-compose exec localstack cat ~/.aws/credentials

# List queues
docker-compose exec localstack awslocal sqs list-queues

# Create queue
docker-compose exec localstack awslocal sqs create-queue --queue-name my-queue

# Send message
docker-compose exec localstack awslocal sqs send-message \
  --queue-url http://localhost:4566/000000000000/interview-queue \
  --message-body '{"key": "value"}'

# Receive message
docker-compose exec localstack awslocal sqs receive-message \
  --queue-url http://localhost:4566/000000000000/interview-queue

# View logs
docker-compose logs -f localstack
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| AWS_ACCESS_KEY_ID | test | Access key for LocalStack |
| AWS_SECRET_ACCESS_KEY | test | Secret key for LocalStack |
| AWS_REGION | us-east-1 | AWS region |
| SQS_QUEUE_URL | http://localstack:4566/... | Queue URL |

## 📝 Files Modified

1. **Created:**
   - `aws/credentials` - AWS access keys
   - `aws/config` - AWS configuration
   - `aws/README.md` - Documentation
   - `verify_setup.sh` - Verification script
   - `AWS_SETUP.md` - This file

2. **Updated:**
   - `docker-compose.yml` - Added volume mounts and env vars
   - `.env.example` - Updated with test credentials
   - `.env` - Updated with test credentials
   - `.gitignore` - Added note about aws/ folder

## ✅ Verification Checklist

After setup, verify:

- [ ] Containers are running: `docker-compose ps`
- [ ] Credentials exist: `ls -la aws/`
- [ ] Credentials mounted: `docker-compose exec localstack cat ~/.aws/credentials`
- [ ] Queue exists: `docker-compose exec localstack awslocal sqs list-queues`
- [ ] Can send message: Test with awslocal
- [ ] Can receive message: Test with awslocal
- [ ] API is healthy: `curl http://localhost:8000/health`

## 🎉 Success!

If all checks pass, your AWS credentials are properly configured and shared with Docker containers!

You can now:
- ✅ Use AWS CLI in containers without credential errors
- ✅ Send messages to SQS from the API
- ✅ Process messages with Lambda
- ✅ Test the complete workflow

---

**Need help?** Run `./verify_setup.sh` to diagnose issues.
