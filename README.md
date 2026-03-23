# Ingapirca League Frontend

## Forced update behavior

At app startup, the client calls `GET /health/public` and reads:

- `app_update.force_update`
- `app_update.min_android_version`
- `app_update.min_ios_version`
- `app_update.android_store_url`
- `app_update.ios_store_url`

If the installed app version is lower than the required minimum for its platform, the app is blocked with a mandatory update screen. User cannot navigate into login/home until updated.

## Local run

```bash
flutter pub get
flutter run
```
