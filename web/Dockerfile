FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
COPY templates ./templates
ARG APP_VERSION=dev
ENV PYTHONUNBUFFERED=1 APP_VERSION=${APP_VERSION}
EXPOSE 8080
CMD ["waitress-serve", "--port=8080", "app:app"]
