# Quick Start Guide

Get the interview project up and running in 5 minutes!

## Prerequisites

- Docker Desktop installed and running
- Git installed

## Steps

### 1. Clone and Navigate

```bash
cd /home/mrueda/WWW/interview/python
```

### 2. Create Environment File

```bash
cp .env.example .env
```

The default values in `.env.example` work for local development with LocalStack.

### 3. Start All Services

```bash
# Using Docker Compose
docker-compose up -d

# Or using Make
make up
```

This will start:
- PostgreSQL database (port 5432)
- FastAPI application (port 8000)
- LocalStack for AWS services (port 4566)

### 4. Verify Services

```bash
# Check all services are running
docker-compose ps

# View logs
docker-compose logs -f
```

### 5. Access the API

Open your browser and go to:
- **API Documentation**: http://localhost:8000/docs
- **Health Check**: http://localhost:8000/health

### 6. Test the API

#### Create a Task

```bash
curl -X POST "http://localhost:8000/tasks" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "My First Task",
    "description": "Testing the API"
  }'
```

#### List All Tasks

```bash
curl "http://localhost:8000/tasks"
```

#### Get a Specific Task

```bash
curl "http://localhost:8000/tasks/1"
```

### 7. View Database

```bash
# Connect to PostgreSQL
docker-compose exec db psql -U postgres -d interview_db

# Run SQL queries
SELECT * FROM tasks;

# Exit
\q
```

### 8. Run Tests

```bash
# Install dependencies locally (optional)
pip install -r requirements.txt

# Run tests
pytest

# Or run tests in Docker
docker-compose exec api pytest
```

## Common Commands

```bash
# Stop all services
docker-compose down

# Restart services
docker-compose restart

# View API logs
docker-compose logs -f api

# View database logs
docker-compose logs -f db

# Clean up everything (including volumes)
docker-compose down -v
```

## Using Make Commands

If you prefer using Make:

```bash
make up          # Start services
make down        # Stop services
make logs        # View logs
make test        # Run tests
make shell       # Open shell in API container
make db-shell    # Open PostgreSQL shell
make clean       # Clean up everything
```

## API Endpoints Quick Reference

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | API information |
| GET | `/health` | Health check |
| POST | `/tasks` | Create task |
| GET | `/tasks` | List tasks |
| GET | `/tasks/{id}` | Get task |
| PUT | `/tasks/{id}` | Update task |
| DELETE | `/tasks/{id}` | Delete task |
| POST | `/tasks/{id}/process` | Process task |

## Interactive API Documentation

Visit http://localhost:8000/docs to:
- See all available endpoints
- Test API calls directly from the browser
- View request/response schemas
- Download OpenAPI specification

## Troubleshooting

### Services won't start

```bash
# Check if ports are already in use
lsof -i :8000
lsof -i :5432

# Rebuild containers
docker-compose build --no-cache
docker-compose up -d
```

### Database connection errors

```bash
# Wait for database to be ready
docker-compose logs db

# Restart API service
docker-compose restart api
```

### Clear everything and start fresh

```bash
# Stop and remove all containers, networks, and volumes
docker-compose down -v

# Remove all images
docker-compose down --rmi all

# Start fresh
docker-compose up -d --build
```

## Next Steps

1. Read the full [README.md](README.md) for detailed documentation
2. Review [INTERVIEW_QUESTIONS.md](INTERVIEW_QUESTIONS.md) for interview preparation
3. Explore the code in the `app/` directory
4. Try modifying the API and adding new features
5. Deploy to AWS (see README for instructions)

## Support

If you encounter any issues:
1. Check the logs: `docker-compose logs -f`
2. Verify all services are running: `docker-compose ps`
3. Review the README.md troubleshooting section
4. Check Docker Desktop is running and has enough resources

---

**Happy Coding! 🚀**
