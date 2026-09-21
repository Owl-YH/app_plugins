# owl_haptics example

Demonstrates the real Android and iOS `owl_haptics` implementations.

The controls call the native host directly. Select a local iOS development team
in Xcode when installing on an iPhone; do not commit a personal team identifier
to the reusable package.

## Real-device checks

Run the real platform-channel integration test first:

```sh
flutter test integration_test/plugin_integration_test.dart -d <device-id>
```

Install the AOT profile build for tactile review:

```sh
flutter run --profile -d <device-id>
```

Compare `Selection`, all three impacts, all three outcomes, and
`Six-pulse sequence`. Start the sequence and immediately press `Cancel`, start
another effect, or background the App to verify that remaining pulses stop. A
debug/JIT build detached from its debugger is not a valid tactile acceptance
artifact, especially on a prerelease operating system.
