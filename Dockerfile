# 1. Собираем фронтенд (Node.js) - тут всё было ок
FROM node:20-alpine AS frontend-builder
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm install
COPY frontend/ ./
RUN npm run build

# 2. Собираем бэкенд на Rust (ИСПОЛЬЗУЕМ 1.85 ИЛИ ВЫШЕ)
FROM rust:1.85-slim AS backend-builder
# Устанавливаем системные зависимости
RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY . .
# Копируем фронтенд
COPY --from=frontend-builder /app/frontend/out ./frontend/out
# Запускаем сборку
RUN cargo build --release

# 3. Финальный образ
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y libssl3 ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=backend-builder /app/target/release/oxdraw /usr/local/bin/oxdraw

EXPOSE 3000
CMD ["oxdraw"]
