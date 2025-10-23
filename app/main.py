from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.responses import HTMLResponse
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List, Dict, Any
from datetime import datetime
from app.database import get_db, engine, Base
from app.models import Task, TaskStatus
from app.schemas import TaskCreate, TaskResponse, TaskUpdate, MessageResponse
from app.sqs_client import get_sqs_client, SQSClient
from app.config import get_settings
import boto3
import json

# Create database tables
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Interview Project API",
    description="FastAPI backend with AWS SQS, Lambda, and PostgreSQL",
    version="1.0.0"
)

settings = get_settings()


@app.get("/")
async def root():
    return {
        "message": "Welcome to Interview Project API",
        "version": "1.0.0",
        "endpoints": {
            "tasks": "/tasks",
            "health": "/health",
            "admin": "/admin/dashboard",
            "admin_api": "/admin/status"
        }
    }


@app.get("/health")
async def health_check():
    return {"status": "healthy", "environment": settings.environment}


@app.post("/tasks", response_model=TaskResponse, status_code=status.HTTP_201_CREATED)
async def create_task(
    task: TaskCreate,
    db: Session = Depends(get_db),
    sqs_client: SQSClient = Depends(get_sqs_client)
):
    """Create a new task and send it to SQS for processing"""
    # Create task in database
    db_task = Task(
        title=task.title,
        description=task.description,
        status=TaskStatus.PENDING
    )
    db.add(db_task)
    db.commit()
    db.refresh(db_task)

    # Send message to SQS
    try:
        message = {
            "task_id": db_task.id,
            "title": db_task.title,
            "description": db_task.description
        }
        sqs_client.send_message(message)
    except Exception as e:
        # Update task status to failed if SQS send fails
        db_task.status = TaskStatus.FAILED
        db_task.result = f"Failed to send to SQS: {str(e)}"
        db.commit()
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Task created but failed to send to SQS: {str(e)}"
        )

    return db_task


@app.get("/tasks", response_model=List[TaskResponse])
async def list_tasks(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(get_db)
):
    """List all tasks"""
    tasks = db.query(Task).offset(skip).limit(limit).all()
    return tasks


@app.get("/tasks/{task_id}", response_model=TaskResponse)
async def get_task(task_id: int, db: Session = Depends(get_db)):
    """Get a specific task by ID"""
    task = db.query(Task).filter(Task.id == task_id).first()
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Task with id {task_id} not found"
        )
    return task


@app.put("/tasks/{task_id}", response_model=TaskResponse)
async def update_task(
    task_id: int,
    task_update: TaskUpdate,
    db: Session = Depends(get_db)
):
    """Update a task"""
    task = db.query(Task).filter(Task.id == task_id).first()
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Task with id {task_id} not found"
        )

    update_data = task_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(task, field, value)

    db.commit()
    db.refresh(task)
    return task


@app.delete("/tasks/{task_id}", response_model=MessageResponse)
async def delete_task(task_id: int, db: Session = Depends(get_db)):
    """Delete a task"""
    task = db.query(Task).filter(Task.id == task_id).first()
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Task with id {task_id} not found"
        )

    db.delete(task)
    db.commit()
    return MessageResponse(message=f"Task {task_id} deleted successfully")


@app.post("/tasks/{task_id}/process", response_model=MessageResponse)
async def process_task(
    task_id: int,
    db: Session = Depends(get_db),
    sqs_client: SQSClient = Depends(get_sqs_client)
):
    """Manually trigger task processing by sending to SQS"""
    task = db.query(Task).filter(Task.id == task_id).first()
    if not task:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Task with id {task_id} not found"
        )

    try:
        message = {
            "task_id": task.id,
            "title": task.title,
            "description": task.description
        }
        sqs_client.send_message(message)

        task.status = TaskStatus.PENDING
        db.commit()

        return MessageResponse(
            message=f"Task {task_id} sent to SQS for processing",
            task_id=task_id
        )
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Failed to send task to SQS: {str(e)}"
        )


# ============================================================================
# ADMIN ENDPOINTS
# ============================================================================

@app.get("/admin/status")
async def get_admin_status(
    db: Session = Depends(get_db),
    sqs_client: SQSClient = Depends(get_sqs_client)
) -> Dict[str, Any]:
    """Get system status including Lambda, SQS, and database metrics"""

    # Get task statistics from database
    task_stats = db.query(
        Task.status,
        func.count(Task.id).label('count')
    ).group_by(Task.status).all()

    task_counts = {stat.status.value: stat.count for stat in task_stats}
    total_tasks = sum(task_counts.values())

    # Get recent tasks
    recent_tasks = db.query(Task).order_by(Task.created_at.desc()).limit(10).all()

    # Get SQS queue metrics
    try:
        queue_attrs = sqs_client.client.get_queue_attributes(
            QueueUrl=sqs_client.queue_url,
            AttributeNames=['All']
        )
        queue_metrics = {
            'messages_available': int(queue_attrs['Attributes'].get('ApproximateNumberOfMessages', 0)),
            'messages_in_flight': int(queue_attrs['Attributes'].get('ApproximateNumberOfMessagesNotVisible', 0)),
            'messages_delayed': int(queue_attrs['Attributes'].get('ApproximateNumberOfMessagesDelayed', 0)),
        }
    except Exception as e:
        queue_metrics = {'error': str(e)}

    # Get Lambda function info
    try:
        lambda_client = boto3.client(
            'lambda',
            endpoint_url=settings.aws_endpoint_url,
            region_name=settings.aws_region,
            aws_access_key_id=settings.aws_access_key_id,
            aws_secret_access_key=settings.aws_secret_access_key
        )

        # List Lambda functions
        functions = lambda_client.list_functions()
        lambda_info = []

        for lambda_func in functions.get('Functions', []):
            # Get event source mappings
            mappings = lambda_client.list_event_source_mappings(
                FunctionName=lambda_func['FunctionName']
            )

            lambda_info.append({
                'name': lambda_func['FunctionName'],
                'runtime': lambda_func['Runtime'],
                'last_modified': lambda_func['LastModified'],
                'timeout': lambda_func['Timeout'],
                'memory_size': lambda_func['MemorySize'],
                'event_sources': len(mappings.get('EventSourceMappings', [])),
                'state': mappings['EventSourceMappings'][0]['State'] if mappings.get('EventSourceMappings') else 'N/A'
            })
    except Exception as e:
        lambda_info = [{'error': str(e)}]

    return {
        'timestamp': datetime.now().isoformat(),
        'database': {
            'total_tasks': total_tasks,
            'by_status': task_counts,
            'recent_tasks': [
                {
                    'id': task.id,
                    'title': task.title,
                    'status': task.status.value,
                    'created_at': task.created_at.isoformat() if task.created_at else None,
                    'updated_at': task.updated_at.isoformat() if task.updated_at else None
                }
                for task in recent_tasks
            ]
        },
        'sqs': {
            'queue_name': 'interview-queue',
            'queue_url': sqs_client.queue_url,
            'metrics': queue_metrics
        },
        'lambda': {
            'functions': lambda_info
        }
    }


@app.get("/admin/dashboard", response_class=HTMLResponse)
async def admin_dashboard():
    """Web-based admin dashboard"""
    html_content = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Admin Dashboard - Interview Project</title>
        <style>
            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }

            body {
                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
                background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
                min-height: 100vh;
                padding: 20px;
            }

            .container {
                max-width: 1400px;
                margin: 0 auto;
            }

            .header {
                background: white;
                padding: 30px;
                border-radius: 10px;
                box-shadow: 0 4px 6px rgba(0,0,0,0.1);
                margin-bottom: 30px;
            }

            h1 {
                color: #333;
                margin-bottom: 10px;
            }

            .subtitle {
                color: #666;
                font-size: 14px;
            }

            .grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
                gap: 20px;
                margin-bottom: 30px;
            }

            .card {
                background: white;
                padding: 25px;
                border-radius: 10px;
                box-shadow: 0 4px 6px rgba(0,0,0,0.1);
            }

            .card h2 {
                color: #333;
                font-size: 18px;
                margin-bottom: 15px;
                display: flex;
                align-items: center;
                gap: 10px;
            }

            .icon {
                font-size: 24px;
            }

            .metric {
                display: flex;
                justify-content: space-between;
                padding: 10px 0;
                border-bottom: 1px solid #eee;
            }

            .metric:last-child {
                border-bottom: none;
            }

            .metric-label {
                color: #666;
                font-size: 14px;
            }

            .metric-value {
                color: #333;
                font-weight: 600;
                font-size: 16px;
            }

            .status-badge {
                display: inline-block;
                padding: 4px 12px;
                border-radius: 20px;
                font-size: 12px;
                font-weight: 600;
            }

            .status-pending { background: #fef3c7; color: #92400e; }
            .status-processing { background: #dbeafe; color: #1e40af; }
            .status-completed { background: #d1fae5; color: #065f46; }
            .status-failed { background: #fee2e2; color: #991b1b; }

            .task-list {
                max-height: 400px;
                overflow-y: auto;
            }

            .task-item {
                padding: 12px;
                border-bottom: 1px solid #eee;
                display: flex;
                justify-content: space-between;
                align-items: center;
            }

            .task-item:hover {
                background: #f9fafb;
            }

            .task-info {
                flex: 1;
            }

            .task-id {
                color: #666;
                font-size: 12px;
                margin-bottom: 4px;
            }

            .task-title {
                color: #333;
                font-weight: 500;
                font-size: 14px;
            }

            .refresh-btn {
                background: #667eea;
                color: white;
                border: none;
                padding: 12px 24px;
                border-radius: 6px;
                cursor: pointer;
                font-size: 14px;
                font-weight: 600;
                transition: background 0.3s;
            }

            .refresh-btn:hover {
                background: #5568d3;
            }

            .loading {
                text-align: center;
                padding: 40px;
                color: #666;
            }

            .error {
                background: #fee2e2;
                color: #991b1b;
                padding: 15px;
                border-radius: 6px;
                margin-bottom: 20px;
            }

            .last-updated {
                text-align: center;
                color: white;
                margin-top: 20px;
                font-size: 14px;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <div class="header">
                <h1>🎛️ Admin Dashboard</h1>
                <p class="subtitle">Monitor Lambda, SQS, and Task Processing</p>
            </div>

            <div id="error-message" style="display: none;" class="error"></div>

            <div id="dashboard-content">
                <div class="loading">Loading dashboard...</div>
            </div>

            <div style="text-align: center; margin-top: 20px;">
                <button class="refresh-btn" onclick="loadDashboard()">🔄 Refresh</button>
            </div>

            <div class="last-updated" id="last-updated"></div>
        </div>

        <script>
            async function loadDashboard() {
                try {
                    const response = await fetch('/admin/status');
                    const data = await response.json();

                    document.getElementById('error-message').style.display = 'none';
                    renderDashboard(data);

                    const now = new Date().toLocaleString();
                    document.getElementById('last-updated').textContent = `Last updated: ${now}`;
                } catch (error) {
                    document.getElementById('error-message').textContent = `Error loading dashboard: ${error.message}`;
                    document.getElementById('error-message').style.display = 'block';
                }
            }

            function renderDashboard(data) {
                const content = `
                    <div class="grid">
                        <!-- Database Stats -->
                        <div class="card">
                            <h2><span class="icon">📊</span> Database</h2>
                            <div class="metric">
                                <span class="metric-label">Total Tasks</span>
                                <span class="metric-value">${data.database.total_tasks}</span>
                            </div>
                            <div class="metric">
                                <span class="metric-label">Pending</span>
                                <span class="metric-value">${data.database.by_status.PENDING || 0}</span>
                            </div>
                            <div class="metric">
                                <span class="metric-label">Processing</span>
                                <span class="metric-value">${data.database.by_status.PROCESSING || 0}</span>
                            </div>
                            <div class="metric">
                                <span class="metric-label">Completed</span>
                                <span class="metric-value">${data.database.by_status.COMPLETED || 0}</span>
                            </div>
                            <div class="metric">
                                <span class="metric-label">Failed</span>
                                <span class="metric-value">${data.database.by_status.FAILED || 0}</span>
                            </div>
                        </div>

                        <!-- SQS Queue -->
                        <div class="card">
                            <h2><span class="icon">📬</span> SQS Queue</h2>
                            <div class="metric">
                                <span class="metric-label">Queue Name</span>
                                <span class="metric-value">${data.sqs.queue_name}</span>
                            </div>
                            <div class="metric">
                                <span class="metric-label">Messages Available</span>
                                <span class="metric-value">${data.sqs.metrics.messages_available || 0}</span>
                            </div>
                            <div class="metric">
                                <span class="metric-label">Messages In Flight</span>
                                <span class="metric-value">${data.sqs.metrics.messages_in_flight || 0}</span>
                            </div>
                            <div class="metric">
                                <span class="metric-label">Messages Delayed</span>
                                <span class="metric-value">${data.sqs.metrics.messages_delayed || 0}</span>
                            </div>
                        </div>

                        <!-- Lambda Functions -->
                        <div class="card">
                            <h2><span class="icon">⚡</span> Lambda Functions</h2>
                            ${data.lambda.functions.map(func => `
                                <div class="metric">
                                    <span class="metric-label">${func.name || 'N/A'}</span>
                                    <span class="metric-value">${func.state || func.error || 'N/A'}</span>
                                </div>
                                ${func.runtime ? `
                                <div class="metric">
                                    <span class="metric-label">Runtime</span>
                                    <span class="metric-value">${func.runtime}</span>
                                </div>
                                ` : ''}
                            `).join('')}
                        </div>
                    </div>

                    <!-- Recent Tasks -->
                    <div class="card">
                        <h2><span class="icon">📋</span> Recent Tasks</h2>
                        <div class="task-list">
                            ${data.database.recent_tasks.map(task => `
                                <div class="task-item">
                                    <div class="task-info">
                                        <div class="task-id">Task #${task.id}</div>
                                        <div class="task-title">${task.title}</div>
                                    </div>
                                    <span class="status-badge status-${task.status.toLowerCase()}">
                                        ${task.status}
                                    </span>
                                </div>
                            `).join('')}
                        </div>
                    </div>
                `;

                document.getElementById('dashboard-content').innerHTML = content;
            }

            // Load dashboard on page load
            loadDashboard();

            // Auto-refresh every 10 seconds
            setInterval(loadDashboard, 10000);
        </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content)
