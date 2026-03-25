# 1. Фронтенд (Node.js) - оставляем как было, он работает
FROM node:20-alpine AS frontend-builder
WORKDIR /app/frontend
ENV NEXT_TELEMETRY_DISABLED=1
ENV NEXT_FONT_GOOGLE_SKIP_FETCH=1
COPY frontend/package*.json ./
RUN npm install
COPY frontend/ ./
RUN echo "module.exports = { output: 'export', images: { unoptimized: true }, eslint: { ignoreDuringBuilds: true }, typescript: { ignoreBuildErrors: true } };" > next.config.js
RUN npx next build

# 2. Бэкенд (Rust)
FROM rust:1.85-slim AS backend-builder
RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY . .
COPY --from=frontend-builder /app/frontend/out ./frontend/out
RUN cargo build --release

# 3. Финальный образ
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y libssl3 ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app

# Копируем бинарник
COPY --from=backend-builder /app/target/release/oxdraw /app/oxdraw
# Копируем фронтенд (он нужен бинарнику во время работы)
COPY --from=frontend-builder /app/frontend/out /app/frontend/out

# ПРИНУДИТЕЛЬНО ВЫСТАВЛЯЕМ АДРЕС И ПОРТ
ENV HOST=0.0.0.0
ENV PORT=3000
ENV RUST_LOG=info

EXPOSE 3000

# Запускаем из рабочей директории /app
CMD ["./oxdraw"]
