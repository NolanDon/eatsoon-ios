# iOS build setup

Use Flutter **3.47.6** (Dart **3.13.5**) and Xcode with the iOS SDK.

```sh
flutter pub get
(cd ios && pod install --repo-update)
open ios/Runner.xcworkspace
flutter analyze
flutter test
flutter build ipa --export-options-plist=ios/ExportOptions.plist
```

The bundle ID is `com.boxill.eatsoon`. Runner and RunnerTests use automatic
signing with Apple Developer team `J2YS94X2X7`. Sign into that team in Xcode
to obtain profiles matching your local signing identities. Local export uses
automatic App Store Connect signing. The bundled manual profile is retained
for reference; it may require a different distribution certificate.

CocoaPods dependencies are locked in `ios/Podfile.lock`. iOS 15 is the minimum
deployment target. Debug, Release, and Profile each include their corresponding
Pods configuration. Run `flutter pub get` before opening Xcode on a fresh clone;
generated Flutter settings and plugin registration files are not versioned.

CI uses the existing `Boxill Apple` integration to fetch signing files, import
certificates, and apply profiles before producing an IPA. Its export options
come from `xcode-project use-profiles`. Existing TestFlight publishing remains
configured. Remote CI runs have not been manually triggered during this audit.

## Local validation

Analysis, the existing Flutter tests, the iOS release build, and a signed
App Store IPA export passed on October 4, 2026. The exported profile matches
the app bundle ID and the available distribution identity.
