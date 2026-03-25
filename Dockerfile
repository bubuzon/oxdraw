# --- 1. СБОРКА ФРОНТЕНДА ---
FROM node:20-alpine AS frontend-builder
WORKDIR /app/frontend
ENV NEXT_TELEMETRY_DISABLED=1
ENV NEXT_FONT_GOOGLE_SKIP_FETCH=1
COPY frontend/package*.json ./
RUN npm install
COPY frontend/ ./
RUN echo "module.exports = { output: 'export', images: { unoptimized: true }, eslint: { ignoreDuringBuilds: true }, typescript: { ignoreBuildErrors: true } };" > next.config.js
RUN npx next build

# --- 2. СБОРКА БЭКЕНДА ---
FROM rust:1.85-slim AS backend-builder
RUN apt-get update && apt-get install -y pkg-config libssl-dev curl tar ca-certificates && rm -rf /var/lib/apt/lists/*

# Качаем D2 напрямую с GitHub (версия v0.6.9)
RUN curl -L https://github.com/terrastruct/d2/releases/download/v0.6.9/d2-v0.6.9-linux-amd64.tar.gz -o d2.tar.gz && \
    tar -xzf d2.tar.gz && \
    mv d2-v0.6.9/bin/d2 /usr/local/bin/d2 && \
    rm -rf d2.tar.gz d2-v0.6.9

WORKDIR /app
COPY . .
COPY --from=frontend-builder /app/frontend/out ./frontend/out
RUN cargo build --release

# --- 3. ФИНАЛЬНЫЙ ОБРАЗ ---
FROM debian:bookworm-slim
# Устанавливаем шрифты (КРИТИЧНО для работы D2)
RUN apt-get update && apt-get install -y \
    libssl3 \
    ca-certificates \
    fontconfig \
    fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Копируем бинарники и статику
COPY --from=backend-builder /usr/local/bin/d2 /usr/local/bin/d2
COPY --from=backend-builder /app/target/release/oxdraw /app/oxdraw
COPY --from=frontend-builder /app/frontend/out /app/frontend/out

# Переменные для корректной работы
ENV HOST=0.0.0.0
ENV PORT=3000
ENV D2_BIN=/usr/local/bin/d2
ENV HOME=/tmp
ENV RUST_LOG=info

EXPOSE 3000

# Запускаем приложение
CMD ["/app/oxdraw"]
