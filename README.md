# Medical Appointment Scheduling System

A production-grade REST API for managing medical appointments, built with Django REST Framework, PostgreSQL, and Celery for asynchronous task processing.

## Overview

This project implements a comprehensive appointment scheduling system that demonstrates advanced backend engineering practices including API design, database optimization, asynchronous task processing, and production-ready patterns.

### Key Features

- **RESTful API** for managing doctors, patients, specialties, and appointments
- **Database Optimization** with advanced ORM techniques (select_related, prefetch_related)
- **Asynchronous Processing** using Celery and RabbitMQ for emails and background tasks
- **Scheduled Tasks** with Celery Beat for periodic operations (appointment reminders)
- **Report Generation** for monthly appointment summaries
- **Production-Ready Architecture** with Docker containerization

## Technology Stack

| Component         | Technology              | Version |
| ----------------- | ----------------------- | ------- |
| Backend Framework | Django                  | 4.2+    |
| REST API          | Django REST Framework   | 3.14+   |
| Database          | PostgreSQL              | 14+     |
| Task Queue        | Celery                  | 5.3+    |
| Message Broker    | RabbitMQ                | 3.12+   |
| Containerization  | Docker & Docker Compose | Latest  |
| Testing           | pytest-django           | Latest  |

## Project Structure

```
medical-appointment-system/
├── manage.py
├── requirements.txt
├── docker-compose.yml
├── Dockerfile
├── config/
│   ├── settings.py
│   ├── urls.py
│   ├── wsgi.py
│   └── celery.py
├── appointments/
│   ├── models.py
│   ├── serializers.py
│   ├── views.py
│   ├── urls.py
│   ├── tasks.py
│   ├── migrations/
│   └── tests/
├── doctors/
│   ├── models.py
│   ├── serializers.py
│   ├── views.py
│   ├── urls.py
│   └── tests/
├── patients/
│   ├── models.py
│   ├── serializers.py
│   ├── views.py
│   ├── urls.py
│   └── tests/
└── utils/
    ├── email_templates/
    └── report_generators.py
```

## Data Models

### Core Entities

**Doctor**

- Name, email, phone number
- Specialties (many-to-many relationship)
- Available time slots

**Patient**

- Name, email, phone number, date of birth
- Medical history (optional)

**Specialty**

- Name, description
- Associated doctors (many-to-many relationship)

**Appointment**

- Doctor (foreign key)
- Patient (foreign key)
- Scheduled datetime
- Status (pending, confirmed, completed, cancelled)
- Notes

### Database Relationships

```
Doctor ←→ Specialty (Many-to-Many)
Doctor ← Appointment → Patient
Patient → Appointment
```

## API Endpoints

### Doctors

- `GET /api/doctors/` - List all doctors with specialties (optimized query)
- `GET /api/doctors/{id}/` - Retrieve doctor details
- `POST /api/doctors/` - Create a new doctor
- `PUT /api/doctors/{id}/` - Update doctor information
- `DELETE /api/doctors/{id}/` - Delete doctor

### Patients

- `GET /api/patients/` - List all patients
- `POST /api/patients/` - Register a new patient
- `GET /api/patients/{id}/` - Retrieve patient details
- `PUT /api/patients/{id}/` - Update patient information

### Appointments

- `GET /api/appointments/` - List appointments with filters (date, doctor, patient)
- `POST /api/appointments/` - Schedule a new appointment
- `GET /api/appointments/{id}/` - Retrieve appointment details
- `PUT /api/appointments/{id}/` - Update appointment status
- `DELETE /api/appointments/{id}/` - Cancel appointment

### Reports

- `GET /api/reports/monthly/{doctor_id}/` - Generate monthly report for a doctor
- `GET /api/reports/monthly/{doctor_id}/download/` - Download report as PDF/CSV

## Getting Started

### Prerequisites

- Docker and Docker Compose installed
- Python 3.10+ (if running locally without Docker)
- PostgreSQL 14+ (if running locally)
- RabbitMQ 3.12+ (if running locally)

### Installation

#### Option 1: Using Docker Compose (Recommended)

```bash
# Clone the repository
git clone <repository-url>
cd medical-appointment-system

# Build and start all services
docker-compose up -d

# Run migrations
docker-compose exec web python manage.py migrate

# Create a superuser
docker-compose exec web python manage.py createsuperuser

# Populate with sample data (optional)
docker-compose exec web python manage.py seed_data
```

The API will be available at `http://localhost:8000/api/`

#### Option 2: Local Development Setup

```bash
# Clone the repository
git clone <repository-url>
cd medical-appointment-system

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Configure environment variables
cp .env.example .env

# Run migrations
python manage.py migrate

# Start the development server
python manage.py runserver

# In another terminal, start Celery worker
celery -A config worker -l info

# In another terminal, start Celery Beat (for scheduled tasks)
celery -A config beat -l info
```

## Configuration

### Environment Variables

Create a `.env` file in the project root:

```env
# Django
DEBUG=True
SECRET_KEY=your-secret-key-here
ALLOWED_HOSTS=localhost,127.0.0.1

# Database
DB_ENGINE=django.db.backends.postgresql
DB_NAME=medical_appointments
DB_USER=postgres
DB_PASSWORD=postgres
DB_HOST=db
DB_PORT=5432

# RabbitMQ
CELERY_BROKER_URL=amqp://guest:guest@rabbitmq:5672//
CELERY_RESULT_BACKEND=redis://redis:6379/0

# Email Configuration
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.gmail.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=your-email@gmail.com
EMAIL_HOST_PASSWORD=your-app-password
```

## Key Implementation Details

### 1. Database Optimization

#### N+1 Query Problem Resolution

The `/api/doctors/` endpoint demonstrates optimization techniques:

```python
# Without optimization: N+1 queries
doctors = Doctor.objects.all()

# With optimization: 2 queries total
doctors = Doctor.objects.prefetch_related('specialties').select_related('user')
```

**Learning Outcome:** Use Django Debug Toolbar to identify N+1 queries and apply `select_related()` for ForeignKey/OneToOne and `prefetch_related()` for ManyToMany relationships.

### 2. Asynchronous Task Processing

#### Email Notifications

When an appointment is created, an email confirmation is sent asynchronously:

```python
# In views.py
from appointments.tasks import send_appointment_confirmation

appointment = Appointment.objects.create(...)
send_appointment_confirmation.delay(appointment.id)
```

**Learning Outcome:** Decouple long-running operations from the request/response cycle using Celery tasks.

#### Scheduled Reminders

A periodic task runs every hour to send appointment reminders:

```python
# In celery.py (Celery Beat configuration)
from celery.schedules import crontab

app.conf.beat_schedule = {
    'send-appointment-reminders': {
        'task': 'appointments.tasks.send_appointment_reminders',
        'schedule': crontab(minute=0),  # Every hour
    },
}
```

**Learning Outcome:** Use Celery Beat for scheduling recurring tasks without external cron jobs.

#### Report Generation

Monthly reports are generated asynchronously and can be downloaded:

```python
# In tasks.py
@app.task
def generate_monthly_report(doctor_id, month, year):
    # Complex aggregation and PDF generation
    # This runs in the background without blocking the API
    pass
```

**Learning Outcome:** Handle computationally expensive operations in background workers.

### 3. Resilience and Error Handling

#### Retry Logic

Tasks can be configured to retry with exponential backoff:

```python
@app.task(bind=True, max_retries=3, default_retry_delay=60)
def send_appointment_confirmation(self, appointment_id):
    try:
        # Send email logic
        pass
    except Exception as exc:
        # Retry after 60 seconds, then 120, then 240
        raise self.retry(exc=exc, countdown=60 * (2 ** self.request.retries))
```

**Learning Outcome:** Implement resilient asynchronous systems that gracefully handle failures.

### 4. Schema Migrations

Safe schema evolution in production:

```bash
# Create a migration after model changes
python manage.py makemigrations

# Review the migration file before applying
cat appointments/migrations/0002_add_appointment_notes.py

# Apply migration (can be rolled back if needed)
python manage.py migrate

# Rollback if necessary
python manage.py migrate appointments 0001
```

**Learning Outcome:** Understand how to manage database schema changes safely in production environments.

## Testing

### Running Tests

```bash
# Run all tests
pytest

# Run tests with coverage
pytest --cov=.

# Run specific test module
pytest appointments/tests/test_models.py

# Run tests in Docker
docker-compose exec web pytest
```

### Test Structure

```
appointments/tests/
├── test_models.py          # Model tests
├── test_serializers.py     # Serializer validation tests
├── test_views.py           # API endpoint tests
├── test_tasks.py           # Celery task tests
└── factories.py            # Test data factories
```

## Performance Monitoring

### Django Debug Toolbar

In development, the Django Debug Toolbar provides insights into:

- SQL queries executed
- Query execution time
- Template rendering time
- Cache hits/misses

Access at `http://localhost:8000/__debug__/` when `DEBUG=True`

### Celery Monitoring

Monitor task execution with Flower:

```bash
# Start Flower (web UI for Celery)
celery -A config flower

# Access at http://localhost:5555
```

## Production Deployment

### Docker Compose Production Setup

```yaml
# docker-compose.prod.yml
version: "3.9"

services:
  web:
    image: medical-appointment-system:latest
    environment:
      DEBUG: "False"
    # Additional production configurations
```

### Deployment Steps

1. Set `DEBUG=False` in environment variables
2. Configure allowed hosts
3. Set up HTTPS/SSL certificates
4. Configure database backups
5. Set up monitoring and logging
6. Configure Celery worker scaling

## Learning Outcomes

By completing this project, you will have mastered:

1. **Django REST Framework:**
   - ViewSets and Serializers
   - Filtering, pagination, and ordering
   - Custom permissions and authentication
   - Error handling and validation

2. **Database Optimization:**
   - Identifying and resolving N+1 query problems
   - Using `select_related()` and `prefetch_related()`
   - Query analysis with Django Debug Toolbar
   - Efficient aggregations and annotations

3. **Asynchronous Processing:**
   - Celery task definition and execution
   - Task routing and priority queues
   - Retry logic and error handling
   - Celery Beat for scheduled tasks

4. **Production Patterns:**
   - Docker containerization
   - Environment configuration management
   - Database migrations and schema evolution
   - Monitoring and logging

## Troubleshooting

### Common Issues

**Issue:** Celery tasks not executing

```bash
# Check if RabbitMQ is running
docker-compose logs rabbitmq

# Check Celery worker logs
docker-compose logs celery-worker
```

**Issue:** Database connection errors

```bash
# Verify PostgreSQL is running
docker-compose logs db

# Check database credentials in .env
```

**Issue:** N+1 query problems

```bash
# Enable Django Debug Toolbar to identify problematic queries
# Add django_extensions to INSTALLED_APPS
# Use shell_plus for interactive debugging
python manage.py shell_plus
```

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Create a feature branch (`git checkout -b feature/amazing-feature`)
2. Write tests for new functionality
3. Ensure all tests pass (`pytest`)
4. Commit with clear messages (`git commit -m 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Resources

### Documentation

- [Django Documentation](https://docs.djangoproject.com/)
- [Django REST Framework](https://www.django-rest-framework.org/)
- [Celery Documentation](https://docs.celeryproject.org/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

### Recommended Reading

- "Two Scoops of Django" by Audrey Roy Greenfeld and Daniel Roy Greenfeld
- "High Performance Django" by Peter Baumgartner and Yann Moulton
- Celery Best Practices Guide

## Support

For issues, questions, or suggestions, please open an issue on the repository or contact the development team.

---

**Last Updated:** 2026-05-10  
**Status:** Active Development
