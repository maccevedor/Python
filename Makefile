.PHONY: help build up down restart logs test clean migrate

help:
	@echo "Available commands:"
	@echo "  make build     - Build Docker images"
	@echo "  make up        - Start all services"
	@echo "  make down      - Stop all services"
	@echo "  make restart   - Restart all services"
	@echo "  make logs      - View logs"
	@echo "  make test      - Run tests"
	@echo "  make clean     - Clean up containers and volumes"
	@echo "  make migrate   - Run database migrations"
	@echo "  make shell     - Open shell in API container"
	@echo "  make db-shell  - Open PostgreSQL shell"

build:
	docker-compose build

up:
	docker-compose up -d
	@echo "Services started. API available at http://localhost:8000"
	@echo "API docs available at http://localhost:8000/docs"

down:
	docker-compose down

restart:
	docker-compose restart

logs:
	docker-compose logs -f

logs-api:
	docker-compose logs -f api

logs-db:
	docker-compose logs -f db

test:
	pytest -v

test-coverage:
	pytest --cov=app --cov-report=html --cov-report=term

clean:
	docker-compose down -v
	rm -rf __pycache__ .pytest_cache .coverage htmlcov
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete

migrate:
	docker-compose exec api alembic upgrade head

migrate-create:
	docker-compose exec api alembic revision --autogenerate -m "$(message)"

shell:
	docker-compose exec api /bin/bash

db-shell:
	docker-compose exec db psql -U postgres -d interview_db

install:
	pip install -r requirements.txt

format:
	black app/ tests/
	isort app/ tests/

lint:
	flake8 app/ tests/
	mypy app/
