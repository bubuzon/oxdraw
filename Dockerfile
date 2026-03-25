# 1. Собираем фронтенд (Node.js)
FROM node:20-alpine AS frontend-builder
WORKDIR /app/frontend

ENV NEXT_TELEMETRY_DISABLED=1
ENV NEXT_FONT_GOOGLE_SKIP_FETCH=1

COPY frontend/package*.json ./
RUN npm install

COPY frontend/ ./

# Пишем конфиг в одну строку, чтобы избежать проблем с переносами
RUN echo "module.exports = { output: 'export', images: { unoptimized: true }, eslint: { ignoreDuringBuilds: true }, typescript: { ignoreBuildErrors: true } };" > next.config.js

# Запускаем сборку фронта
RUN npx next build

# 2. Собираем бэкенд на Rust
FROM rust:1.85-slim AS backend-builder
RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY . .
# Копируем результат сборки фронта
COPY --from=frontend-builder /app/frontend/out ./frontend/out
RUN cargo build --release

# 3. Финальный образ
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y libssl3 ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=backend-builder /app/target/release/oxdraw /usr/local/bin/oxdraw

EXPOSE 3000
CMD ["oxdraw"]
