FROM python:3.12-slim

WORKDIR /app

COPY server.py /app/server.py
COPY public /app/public

RUN mkdir -p /app/data

ENV PORT=8080
EXPOSE 8080

VOLUME ["/app/data"]

CMD ["python3", "server.py"]
