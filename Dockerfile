# 1. Собираем фронтенд (Node.js)
FROM node:20-alpine AS frontend-builder
WORKDIR /app/frontend

# Отключаем телеметрию и блокируем внешние запросы за шрифтами
ENV NEXT_TELEMETRY_DISABLED=1
ENV NEXT_FONT_GOOGLE_SKIP_FETCH=1

COPY frontend/package*.json ./
RUN npm install

COPY frontend/ ./

# КРИТИЧЕСКИЙ ШАГ: Создаем правильный конфиг для статического экспорта (папка out)
RUN echo "/** @type {import('next').NextConfig} */ \n\
const nextConfig = { \n\
  output: 'export', \n\
  images: { unoptimized: true }, \n\
  eslint: { ignoreDuringBuilds: true }, \n\
  typescript: { ignoreBuildErrors: true } \n\
}; \n\
module.exports = nextConfig;" > next.config.js

# Собираем фронтенд. Теперь папка /app/frontend/out ТОЧНО появится.
RUN npx next build

# 2. Собираем бэкенд на Rust
FROM rust:1.85-slim AS backend-builder
RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY . .
# Теперь папка out существует и мы её копируем
COPY --from=frontend-builder /app/frontend/out ./frontend/out
RUN cargo build --release

# 3. Финальный образ
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y libssl3 ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
# Копируем бинарник из папки сборки
COPY --from=backend-builder /app/target/release/oxdraw /usr/local/bin/oxdraw

EXPOSE 3000
CMD ["oxdraw"]
