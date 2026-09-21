# Migrate to the shared GroMore runtime

The GroMore SDK has process-wide initialization and privacy state. The Flutter
provider therefore exposes one runtime per Dart isolate while retaining one
independent ad session per placement.

Replace direct construction:

```dart
final ads = GroMoreAds(config);
```

with:

```dart
final ads = GroMoreAds.configure(config);
```

Equivalent configuration returns the identical object. A different App ID,
unit map, access configuration, or debug setting fails with
`configurationConflict`. After terminal `dispose`, the runtime cannot be
recreated in the same isolate; restart the app/engine instead.

In Riverpod, keep the repository/provider application-scoped (do not use
`autoDispose`). Pages own only their event subscription:

```dart
final adsProvider = Provider<Ads>((ref) {
  return GroMoreAds.configure(buildGroMoreConfig());
});
```

Different placements can still load concurrently. The singleton restriction
applies only to the provider runtime, not to reward or insert sessions.

For a future direct Google integration, create a separate provider package that
implements `Ads` and select it at the composition root. Do not add a global
`Ads.instance`, and do not race GroMore and Google requests in feature code.
