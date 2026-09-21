# Android host integration

## Base repository and dependency ownership

The plugin pins the GroMore fusion/mediation base AAR. The consuming Android
build must make ByteDance's official repository visible to all projects. With a
modern Flutter Kotlin DSL project:

```kotlin
// android/build.gradle.kts
allprojects {
    repositories {
        google()
        mavenCentral()
        maven(url = "https://artifact.bytedance.com/repository/pangle")
    }
}
```

The resolved base must be exactly:

```text
com.pangle.cn:mediation-sdk:7.7.1.6
com.squareup.okhttp3:okhttp:3.12.1
```

Do not add standalone Pangle beside the mediation SDK. Do not use `latest`,
`+`, beta-example coordinates, or a different fusion version.

The host owns optional ADN SDKs and adapters. Add only the networks selected in
the GroMore console, using an exact pair from `versions.md` and the coordinate
or local artifact supplied by that same authenticated official download. The
plugin deliberately does not guess or publish coordinates omitted by the
official bundle.

## Credentials and manifest review

Supply App ID and Code IDs outside source control (for example with
`--dart-define-from-file`). Do not put a reusable credential in this package or
the Android manifest.

The base AAR contributes its documented activities, services, providers,
queries, resources, basic network permissions, and its official consumer
shrinker rules through manifest/AAR merging. The plugin declares only
`INTERNET` and `ACCESS_NETWORK_STATE` itself. Inspect the release merged
manifest: the base SDK can contribute storage, Wi-Fi, notification, download,
live, and identifier-related declarations. The host must reconcile every
permission and package query with its privacy policy and the selected GroMore
features. This plugin never requests a runtime permission.

The pinned base contains download-notification code but does not declare
Android 13's `POST_NOTIFICATIONS` permission. The example suppresses the lint
finding instead of silently expanding host permissions. If the host enables a
feature that genuinely needs download notifications, the host must declare,
explain, and request that runtime permission itself.

Keep HTTPS access to GroMore and every enabled ADN endpoint. Do not enable
application-wide cleartext traffic as a generic fix; apply only a network
security exception explicitly required by a selected network's current
official integration guide.

## Shrinking and release verification

The dependency's own `proguard.txt` is consumed automatically. The plugin adds
consumer rules for its Flutter entry point and generated Pigeon bridge, plus
narrow `-dontwarn` entries for compile-time/optional classes actually reported
by R8 for the pinned AAR. Do not replace these with broad `-ignorewarnings`, and
do not disable R8 to hide a release-only integration error.

Before release:

```sh
flutter build apk --release --dart-define-from-file=dart_defines.json
cd android
./gradlew app:dependencies --configuration releaseRuntimeClasspath
./gradlew app:processReleaseMainManifest
```

Inspect the dependency report and APK/AAB: it must contain the pinned mediation
base and only the optional ADNs deliberately selected by the host. Run the
minified release on an API-24-or-newer physical device.
