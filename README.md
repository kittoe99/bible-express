# Bible Xpress

KJV reader with AI explanations and synced progress.

## Platforms

- **Web / iPhone PWA** — open the site in Safari → Share → **Add to Home Screen**
- **Linux desktop** — build with `flutter build linux --release`
- **Android** — `flutter build apk`

## Deploy (DigitalOcean App Platform)

This repo includes a `Dockerfile` that builds Flutter web and serves it with nginx.

App Platform uses `.do/app.yaml` (or create an app pointing at this GitHub repo with the Dockerfile).

## Local web

```bash
flutter pub get
flutter run -d chrome
# or
flutter build web --release
```
