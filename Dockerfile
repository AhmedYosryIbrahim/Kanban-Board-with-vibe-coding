FROM ghcr.io/cirruslabs/flutter:3.41.8 AS frontend

WORKDIR /build

COPY frontend/pubspec.yaml frontend/pubspec.lock ./
RUN flutter pub get

COPY frontend ./
RUN flutter build web --release


FROM node:22-slim

WORKDIR /app

COPY backend/package.json backend/package-lock.json ./
RUN npm ci --omit=dev

COPY backend/src ./src
COPY --from=frontend /build/build/web ./public

ENV PORT=3000
EXPOSE 3000

CMD ["node", "src/server.js"]
