# AWS Credentials for LocalStack

This folder contains **test credentials** for LocalStack development.

## ⚠️ Important

These are **NOT real AWS credentials**. They are dummy values used only for local development with LocalStack.

- **Access Key:** `test`
- **Secret Key:** `test`
- **Region:** `us-east-1`

## 🔒 Security

✅ **Safe to commit** - These are test credentials only  
❌ **Never use in production** - Use AWS IAM roles or AWS Secrets Manager  
❌ **Never commit real AWS credentials** - Always use environment variables or secret management

## 📂 Files

- `credentials` - AWS access key and secret key
- `config` - AWS region and output format

## 🐳 Docker Integration

These files are mounted into containers as read-only volumes:

```yaml
volumes:
  - ./aws:/root/.aws:ro
```

This allows all containers (API, LocalStack) to use the same AWS configuration.

## 🔧 Usage

The credentials are automatically available in:
- LocalStack container
- API container
- Any AWS CLI commands

No manual configuration needed!

## 🚀 For Production

In production, use:
- AWS IAM Roles (recommended)
- AWS Secrets Manager
- Environment variables
- AWS Systems Manager Parameter Store

**Never hardcode real credentials!**
