# 🚀 Get Started in 3 Steps

## Step 1: Run Setup Script

```bash
./setup.sh
```

This will:
- ✅ Check Docker is running
- ✅ Create `.env` file
- ✅ Build Docker images
- ✅ Start all services
- ✅ Verify health

## Step 2: Test the API

Open your browser: **http://localhost:8000/docs**

Or use curl:

```bash
# Create a task
curl -X POST "http://localhost:8000/tasks" \
  -H "Content-Type: application/json" \
  -d '{"title": "My First Task", "description": "Testing the API"}'

# List tasks
curl "http://localhost:8000/tasks"
```

## Step 3: Explore

- 📖 **Full Documentation**: `README.md`
- ❓ **Interview Questions**: `INTERVIEW_QUESTIONS.md`
- 🏗️ **Architecture**: `ARCHITECTURE.md`
- 📊 **Project Summary**: `PROJECT_SUMMARY.md`

## Quick Commands

```bash
# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Run tests
docker-compose exec api pytest

# Database shell
docker-compose exec db psql -U postgres -d interview_db
```

## What You Have

✅ **FastAPI Backend** - RESTful API with 8 endpoints
✅ **PostgreSQL Database** - Persistent storage
✅ **AWS SQS** - Message queue (LocalStack)
✅ **AWS Lambda** - Async processor
✅ **Docker Setup** - Complete containerization
✅ **Tests** - Comprehensive test suite
✅ **Documentation** - 5 detailed guides
✅ **Interview Questions** - 20+ technical questions

## Need Help?

1. Check `QUICKSTART.md` for detailed setup
2. Review `README.md` for troubleshooting
3. View logs: `docker-compose logs -f`

**Happy Coding! 🎉**
