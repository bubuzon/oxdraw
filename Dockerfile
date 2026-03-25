# 1. Фронтенд (Node.js) - берем из кэша
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
RUN apt-get update && apt-get install -y pkg-config libssl-dev curl tar ca-certificates && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY . .
COPY --from=frontend-builder /app/frontend/out ./frontend/out
RUN cargo build --release

# 3. Финальный образ
FROM debian:bookworm-slim
# Устанавливаем зависимости, включая ШРИФТЫ (важно для D2)
RUN apt-get update && apt-get install -y \
    libssl3 \
    ca-certificates \
    curl \
    fontconfig \
    libfontconfig1 \
    fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

# Устанавливаем D2
RUN curl -L https://d2lang.com/install.sh | sh -s --
# Делаем симлинк, чтобы oxdraw точно его нашел
RUN ln -sf /usr/local/bin/d2 /usr/bin/d2

WORKDIR /app

# Копируем oxdraw и фронтенд
COPY --from=backend-builder /app/target/release/oxdraw /app/oxdraw
COPY --from=frontend-builder /app/frontend/out /app/frontend/out

# Настройки для D2 и сервера
ENV HOME=/app
ENV HOST=0.0.0.0
ENV PORT=3000
ENV D2_LAYOUT=dagre
ENV RUST_LOG=info

EXPOSE 3000

# Запускаем напрямую
CMD ["/app/oxdraw"]
