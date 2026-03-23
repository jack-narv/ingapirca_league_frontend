# Ingapirca League Frontend (Flutter Web + Railway)

## Local web build

```bash
flutter pub get
flutter build web --release \
  --dart-define=API_BASE_URL=https://YOUR-BACKEND.railway.app
```

## Deploy to Railway (web)

This repo includes:

- `Dockerfile` (build Flutter web + serve with Nginx)
- `nginx.conf` (SPA fallback for Flutter routes)

### Steps

1. Create a new Railway service from this frontend repository/folder.
2. Railway will detect the `Dockerfile` automatically.
3. Set build arg (optional if default backend URL is correct):
   - `API_BASE_URL=https://YOUR-BACKEND.railway.app`
4. Deploy.

## Notes

- Frontend API URL is controlled by compile-time define:
  - `API_BASE_URL`
- If you use a custom domain in Railway, redeploy with the correct backend URL.
