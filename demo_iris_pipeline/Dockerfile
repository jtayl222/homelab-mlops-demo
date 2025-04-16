FROM --platform=$BUILDPLATFORM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --upgrade pip && pip wheel --no-deps -r requirements.txt

FROM --platform=$TARGETPLATFORM python:3.12-slim
WORKDIR /app
ENV PYTHONUNBUFFERED=1
COPY --from=builder /root/.cache/pip /wheels
RUN pip install --no-index /wheels/*
COPY model_server.py .
CMD ["python", "model_server.py"]
