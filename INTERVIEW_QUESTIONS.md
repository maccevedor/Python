# Interview Questions - Python Backend Developer

## Project Overview
This project demonstrates a microservices architecture using FastAPI, AWS SQS, Lambda, PostgreSQL, and Docker.

---

## Section 1: Python & FastAPI (30 minutes)

### Question 1: FastAPI Basics
**Q:** Explain the difference between `def` and `async def` in FastAPI route handlers. When would you use each?

**Expected Answer:**
- `def` is synchronous and blocks the event loop
- `async def` is asynchronous and allows concurrent request handling
- Use `async def` for I/O-bound operations (database queries, API calls)
- Use `def` for CPU-bound operations or when using synchronous libraries

**Follow-up:** How does FastAPI handle dependency injection? Explain the `Depends()` function.

---

### Question 2: Pydantic Models
**Q:** In this project, we use Pydantic for data validation. Explain the purpose of `TaskCreate`, `TaskUpdate`, and `TaskResponse` schemas. Why do we need separate models?

**Expected Answer:**
- Separation of concerns: input validation vs. output serialization
- `TaskCreate`: validates incoming data for creating tasks
- `TaskUpdate`: allows partial updates with optional fields
- `TaskResponse`: controls what data is returned to clients
- Security: prevents exposing internal fields

**Follow-up:** What is `model_dump(exclude_unset=True)` used for in the update endpoint?

---

### Question 3: Database Session Management
**Q:** Look at the `get_db()` function in `database.py`. Explain how this dependency ensures proper database connection handling.

**Expected Answer:**
- Generator function with `yield` ensures cleanup
- Connection is created per request
- `finally` block guarantees connection closure
- Prevents connection leaks
- FastAPI's dependency injection manages the lifecycle

**Follow-up:** What would happen if we forgot the `finally` block?

---

## Section 2: PostgreSQL & SQLAlchemy (20 minutes)

### Question 4: ORM vs Raw SQL
**Q:** This project uses SQLAlchemy ORM. What are the advantages and disadvantages compared to raw SQL queries?

**Expected Answer:**
**Advantages:**
- Type safety and IDE autocomplete
- Database agnostic
- Prevents SQL injection
- Easier to maintain and refactor

**Disadvantages:**
- Performance overhead for complex queries
- Learning curve
- Less control over query optimization
- N+1 query problems

**Follow-up:** When would you choose raw SQL over ORM?

---

### Question 5: Database Migrations
**Q:** How would you add a new field `priority` (integer) to the Task model? Walk through the complete process.

**Expected Answer:**
1. Add field to `Task` model in `models.py`
2. Create migration: `alembic revision --autogenerate -m "add priority field"`
3. Review generated migration file
4. Apply migration: `alembic upgrade head`
5. Update Pydantic schemas if needed
6. Test the changes

**Follow-up:** What happens to existing records when you add a non-nullable field?

---

### Question 6: Database Indexing
**Q:** The `Task` model has `index=True` on the `id` field. Explain when and why you would add indexes to other fields.

**Expected Answer:**
- Indexes speed up queries but slow down writes
- Add indexes to frequently queried fields
- Consider composite indexes for multi-column queries
- `status` field might benefit from an index
- `created_at` for time-based queries
- Trade-off: storage space and write performance

---

## Section 3: AWS Services (25 minutes)

### Question 7: SQS Message Queue
**Q:** Explain why we use SQS in this architecture. What problems does it solve?

**Expected Answer:**
- Decouples services (API and Lambda)
- Asynchronous processing
- Handles traffic spikes (buffering)
- Retry mechanism for failed messages
- Scalability: multiple consumers
- Reliability: message persistence

**Follow-up:** What's the difference between SQS Standard and FIFO queues?

---

### Question 8: Lambda Function Design
**Q:** Review the `lambda_function.py`. What improvements would you suggest for production use?

**Expected Answer:**
- Connection pooling for database
- Better error handling and logging
- Dead letter queue for failed messages
- Idempotency handling (duplicate messages)
- Metrics and monitoring
- Environment-specific configuration
- Batch processing optimization
- Timeout handling

**Follow-up:** How would you handle a message that keeps failing?

---

### Question 9: Message Processing
**Q:** What happens if the Lambda function crashes while processing a message? How does SQS handle this?

**Expected Answer:**
- Message visibility timeout
- Message returns to queue if not deleted
- Retry with exponential backoff
- After max retries, moves to DLQ (if configured)
- Importance of idempotent operations
- Task status tracking in database

---

### Question 10: AWS IAM & Security
**Q:** What IAM permissions would the Lambda function need in a production environment?

**Expected Answer:**
- SQS: ReceiveMessage, DeleteMessage, GetQueueAttributes
- CloudWatch: PutLogEvents, CreateLogStream
- VPC: CreateNetworkInterface (if in VPC)
- Secrets Manager: GetSecretValue (for DB credentials)
- Principle of least privilege

---

## Section 4: Docker & DevOps (20 minutes)

### Question 11: Docker Compose
**Q:** Explain the purpose of the `depends_on` and `healthcheck` configurations in `docker-compose.yml`.

**Expected Answer:**
- `depends_on`: defines service startup order
- `healthcheck`: ensures service is ready before dependents start
- `condition: service_healthy`: waits for health check to pass
- Prevents connection errors during startup
- Important for database initialization

**Follow-up:** What's the difference between `depends_on` with and without health checks?

---

### Question 12: Multi-stage Builds
**Q:** How would you optimize the Dockerfile for production? Suggest improvements.

**Expected Answer:**
- Multi-stage builds to reduce image size
- Use specific Python version tags
- Combine RUN commands to reduce layers
- Use `.dockerignore` file
- Non-root user for security
- Cache pip dependencies separately
- Use slim or alpine base images

---

### Question 13: Environment Configuration
**Q:** How does the application handle different environments (development, staging, production)?

**Expected Answer:**
- Environment variables via `.env` file
- `pydantic-settings` for configuration management
- Different docker-compose files per environment
- LocalStack for local AWS services
- Secrets management for production
- Configuration validation at startup

---

## Section 5: System Design & Architecture (25 minutes)

### Question 14: Scalability
**Q:** This system needs to handle 10,000 requests per minute. What bottlenecks might you encounter and how would you address them?

**Expected Answer:**
**Bottlenecks:**
- Database connections
- SQS throughput
- Lambda concurrency limits
- API server capacity

**Solutions:**
- Database connection pooling
- Read replicas for queries
- Multiple Lambda instances
- API horizontal scaling
- Caching layer (Redis)
- Database query optimization
- Batch processing in Lambda

---

### Question 15: Error Handling & Monitoring
**Q:** How would you implement comprehensive error handling and monitoring for this system?

**Expected Answer:**
- Structured logging (JSON format)
- CloudWatch Logs and Metrics
- Application Performance Monitoring (APM)
- Error tracking (Sentry, Rollbar)
- Health check endpoints
- Alerting on error rates
- Distributed tracing
- Database query monitoring
- SQS queue depth monitoring

---

### Question 16: Testing Strategy
**Q:** Design a comprehensive testing strategy for this application. What types of tests would you write?

**Expected Answer:**
**Unit Tests:**
- Individual functions and methods
- Pydantic model validation
- Business logic

**Integration Tests:**
- API endpoints with test database
- Database operations
- SQS message sending

**E2E Tests:**
- Complete workflow: API → SQS → Lambda → DB
- Docker Compose test environment

**Load Tests:**
- API performance under load
- Database connection handling

---

### Question 17: Database Transaction Management
**Q:** The current implementation doesn't use database transactions explicitly. When would you need to wrap operations in transactions?

**Expected Answer:**
- Multiple related database operations
- Ensuring data consistency
- Rollback on partial failures
- Example: Creating task + sending to SQS
- Use SQLAlchemy's session.begin()
- Consider distributed transactions
- Saga pattern for microservices

---

### Question 18: Security Considerations
**Q:** What security vulnerabilities might exist in this application? How would you address them?

**Expected Answer:**
**Vulnerabilities:**
- SQL injection (mitigated by ORM)
- Missing authentication/authorization
- Exposed AWS credentials
- No rate limiting
- No input sanitization beyond Pydantic

**Solutions:**
- JWT authentication
- Role-based access control
- AWS Secrets Manager
- API rate limiting
- Input validation and sanitization
- HTTPS/TLS
- Security headers
- Audit logging

---

## Section 6: Practical Coding Tasks (30 minutes)

### Task 1: Add Authentication
**Q:** Implement JWT-based authentication for the API. Add a middleware that protects all task endpoints.

**Requirements:**
- Create user model and authentication endpoints
- Generate and validate JWT tokens
- Protect task endpoints
- Associate tasks with users

---

### Task 2: Implement Retry Logic
**Q:** Add retry logic to the SQS client with exponential backoff.

**Requirements:**
- Retry failed SQS operations
- Exponential backoff (1s, 2s, 4s, 8s)
- Maximum 3 retries
- Log each retry attempt

---

### Task 3: Add Pagination
**Q:** Improve the `list_tasks` endpoint with proper pagination.

**Requirements:**
- Cursor-based pagination
- Return total count
- Include next/previous page links
- Efficient database queries

---

### Task 4: Implement Caching
**Q:** Add Redis caching for the `get_task` endpoint.

**Requirements:**
- Cache task data for 5 minutes
- Invalidate cache on updates
- Handle cache misses
- Add cache hit/miss metrics

---

## Section 7: Debugging Scenarios (20 minutes)

### Scenario 1: Memory Leak
**Q:** The API server's memory usage keeps growing. How would you debug this?

**Expected Answer:**
- Check for unclosed database connections
- Profile memory usage (memory_profiler)
- Look for circular references
- Check for large objects in memory
- Review caching implementation
- Monitor with tools like py-spy

---

### Scenario 2: Slow Queries
**Q:** Users report slow response times. How would you identify and fix slow database queries?

**Expected Answer:**
- Enable SQLAlchemy query logging
- Use PostgreSQL's EXPLAIN ANALYZE
- Check for missing indexes
- Look for N+1 query problems
- Use database query monitoring tools
- Optimize queries or add indexes
- Consider query result caching

---

### Scenario 3: Lost Messages
**Q:** Some tasks are created but never processed. How would you debug this?

**Expected Answer:**
- Check SQS queue metrics
- Verify Lambda function is triggered
- Check Lambda logs for errors
- Verify message format
- Check visibility timeout settings
- Look for DLQ messages
- Verify IAM permissions
- Check Lambda concurrency limits

---

## Bonus Questions

### Question 19: Microservices Communication
**Q:** If you were to split this into multiple microservices, how would they communicate?

**Expected Answer:**
- Event-driven architecture
- Message queues (SQS, RabbitMQ)
- REST APIs for synchronous calls
- gRPC for internal services
- Event sourcing
- API Gateway
- Service mesh

---

### Question 20: CI/CD Pipeline
**Q:** Design a CI/CD pipeline for this application.

**Expected Answer:**
**Stages:**
1. Lint and format (black, flake8)
2. Run unit tests
3. Build Docker images
4. Run integration tests
5. Security scanning
6. Deploy to staging
7. Run E2E tests
8. Deploy to production
9. Smoke tests

**Tools:** GitHub Actions, GitLab CI, Jenkins, AWS CodePipeline

---

## Evaluation Criteria

### Junior Level (0-2 years)
- Understands basic FastAPI concepts
- Can write simple CRUD operations
- Basic SQL knowledge
- Understands Docker basics
- Can follow existing patterns

### Mid Level (2-5 years)
- Deep FastAPI and Python knowledge
- Solid database design skills
- Understands AWS services
- Can design scalable systems
- Writes comprehensive tests
- Considers security implications

### Senior Level (5+ years)
- Architectural decision making
- Performance optimization
- Production debugging skills
- Mentoring capability
- Trade-off analysis
- System design expertise
- DevOps and infrastructure knowledge

---

## Additional Resources

- FastAPI Documentation: https://fastapi.tiangolo.com/
- SQLAlchemy Documentation: https://docs.sqlalchemy.org/
- AWS SQS Documentation: https://docs.aws.amazon.com/sqs/
- AWS Lambda Documentation: https://docs.aws.amazon.com/lambda/
- PostgreSQL Documentation: https://www.postgresql.org/docs/
- Docker Documentation: https://docs.docker.com/
