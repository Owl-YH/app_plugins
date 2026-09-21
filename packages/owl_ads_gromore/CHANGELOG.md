# Changelog

## 0.1.0

- Allow a new Dart provider to initialize after the previous provider is
  disposed, while reserving permanent native-host teardown for Flutter engine
  detach.
- Fail and clean up Android reward/insert loads when the native SDK omits its
  callback for 30 seconds.

- Add the typed GroMore reward and full-screen insert provider for Android and
  iOS, with consent gating, Pigeon transport, native lifecycle management, and
  an executable real-credential example.
