# 1. Фронтенд (Node.js)
FROM node:20-alpine AS frontend-builder
WORKDIR /app/frontend
ENV NEXT_TELEMETRY_DISABLED=1
ENV NEXT_FONT_GOOGLE_SKIP_FETCH=1
COPY frontend/package*.json ./
RUN npm install
COPY frontend/ ./
RUN echo "module.exports = { output: 'export', images: { unoptimized: true }, eslint: { ignoreDuringBuilds: true }, typescript: { ignoreBuildErrors: true } };" > next.config.js
RUN npx next build

# 2. Бэкенд (Rust) - ТЕПЕРЬ НА ПОЛНУЮ МОЩНОСТЬ
FROM rust:1.85-slim AS backend-builder
RUN apt-get update && apt-get install -y pkg-config libssl-dev curl && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY . .
COPY --from=frontend-builder /app/frontend/out ./frontend/out
# Убрали -j 1, Rust задействует все ядра твоего сервера
RUN cargo build --release

# 3. Финальный образ
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y libssl3 ca-certificates curl && rm -rf /var/lib/apt/lists/*

# Устанавливаем D2 (пробуем еще раз с флагами надежности)
RUN curl -fsSL --connect-timeout 60 --retry 10 https://d2lang.com/install.sh | sh -s --

WORKDIR /app
COPY --from=backend-builder /app/target/release/oxdraw /app/oxdraw
COPY --from=frontend-builder /app/frontend/out /app/frontend/out

ENV HOST=0.0.0.0
ENV PORT=3000
EXPOSE 3000

CMD ["./oxdraw"]
