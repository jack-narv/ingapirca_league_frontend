FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# Override this at build time if needed:
# --build-arg API_BASE_URL=https://your-backend.railway.app
ARG API_BASE_URL=https://ingapirca-league-backend-production.up.railway.app
RUN flutter build web --release --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginx:alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

ENV PORT=8080
EXPOSE 8080

CMD ["/bin/sh", "-c", "sed -i \"s/__PORT__/${PORT}/g\" /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"]
