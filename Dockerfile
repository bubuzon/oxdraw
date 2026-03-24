# 1. Собираем фронтенд (Node.js)
FROM node:20-alpine AS frontend-builder
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm install
COPY frontend/ ./
RUN npm run build

# 2. Собираем бэкенд на Rust (ОБНОВЛЕННАЯ ВЕРСИЯ)
FROM rust:1.84-slim AS backend-builder
# Устанавливаем зависимости для сборки
RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY . .
# Копируем фронтенд в папку, которую ждет билд-скрипт Rust
COPY --from=frontend-builder /app/frontend/out ./frontend/out
RUN cargo build --release

# 3. Финальный образ
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y libssl3 ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=backend-builder /app/target/release/oxdraw /usr/local/bin/oxdraw

EXPOSE 3000
CMD ["oxdraw"]
