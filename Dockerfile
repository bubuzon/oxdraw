# 1. Собираем фронтенд (Node.js)
FROM node:20-alpine AS frontend-builder
WORKDIR /app/frontend

# Отключаем телеметрию и попытки скачать шрифты извне
ENV NEXT_TELEMETRY_DISABLED=1
ENV NEXT_FONT_GOOGLE_SKIP_FETCH=1

COPY frontend/package*.json ./
RUN npm install

COPY frontend/ ./

# ХАК: Если в проекте нет next.config.js, создадим его с отключенными шрифтами.
# Если есть — подправим, чтобы билд не падал из-за сети.
RUN if [ ! -f next.config.js ]; then \
      echo "module.exports = { optimizeFonts: false };" > next.config.js; \
    fi

# Собираем фронт (без Turbopack, так как он более капризен к сети)
RUN npx next build

# 2. Собираем бэкенд на Rust
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
COPY --from=backend-builder /app/target/release/oxdraw /usr/local/bin/oxdraw

EXPOSE 3000
CMD ["oxdraw"]
