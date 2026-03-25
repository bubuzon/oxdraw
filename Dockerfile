# 1. Фронтенд (Node.js) - Тут всё хорошо, берём из кэша
FROM node:20-alpine AS frontend-builder
WORKDIR /app/frontend
ENV NEXT_TELEMETRY_DISABLED=1
ENV NEXT_FONT_GOOGLE_SKIP_FETCH=1
COPY frontend/package*.json ./
RUN npm install
COPY frontend/ ./
RUN echo "module.exports = { output: 'export', images: { unoptimized: true }, eslint: { ignoreDuringBuilds: true }, typescript: { ignoreBuildErrors: true } };" > next.config.js
RUN npx next build

# 2. Бэкенд (Rust) + Установка D2 прямо сюда
FROM rust:1.85-slim AS backend-builder
RUN apt-get update && apt-get install -y pkg-config libssl-dev curl && rm -rf /var/lib/apt/lists/*

# Сначала устанавливаем D2 в этом слое, чтобы он закэшировался навсегда
RUN curl -fsSL --connect-timeout 60 --retry 10 https://d2lang.com/install.sh | sh -s --

WORKDIR /app
COPY . .
COPY --from=frontend-builder /app/frontend/out ./frontend/out

# Сборка приложения
RUN cargo build --release

# 3. Финальный образ (Минимальный)
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y libssl3 ca-certificates && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Копируем уже установленный бинарник D2 из билдера
COPY --from=backend-builder /usr/local/bin/d2 /usr/local/bin/d2
# Копируем наше приложение
COPY --from=backend-builder /app/target/release/oxdraw /app/oxdraw
COPY --from=frontend-builder /app/frontend/out /app/frontend/out

ENV HOST=0.0.0.0
ENV PORT=3000
EXPOSE 3000

CMD ["./oxdraw"]
