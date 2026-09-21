# owl_ads_gromore example

This app executes only real GroMore requests. It contains no fallback IDs and no
simulated advertising provider.

1. Copy `dart_defines.example.json` to the ignored `dart_defines.json`.
2. Replace every App ID and Code ID with values from the GroMore console, and
   provide the real host user ID plus reward name/amount expected by the SSV
   backend.
3. Run `flutter run --dart-define-from-file=dart_defines.json`.

`GROMORE_TEST_DEVICE_IDS` is retained for the host's debug/test tooling and
release records; the plugin does not invent an SDK mapping where the pinned
GroMore contract exposes none. Android release signing belongs in the ignored
`android/key.properties`; a non-secret template is committed beside it. For
iOS device builds, copy `ios/Flutter/Signing.xcconfig.example` to the ignored
`ios/Flutter/Signing.xcconfig` and set the real Apple development team ID.
