infra-up:
	@echo "Starting infrastructure..."
	@docker-compose up -d

infra-down:
	@echo "Stopping infrastructure..."
	@docker-compose down

create-superuser:
	@echo "Creating superuser..."
	@python manage.py createsuperuser

run:
	@echo "Running application..."
	@python manage.py runserver

migrate:
	@echo "Applying database migrations..."
	@python manage.py migrate