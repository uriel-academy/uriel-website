# Multi-stage Dockerfile for Flutter web static site
FROM ghcr.io/cirruslabs/flutter:latest AS builder
WORKDIR /app
COPY . .
RUN flutter build web --release

FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
