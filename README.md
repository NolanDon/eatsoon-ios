# EatSoon

Review items extracted from a fridge photo, confirm label dates or suggested check intervals, then log used items.

Version 3.0.0 (3013), Flutter for iPhone. Production entrypoint: `lib/main.dart`; dashboard and domain logic: `lib/v3`. Bundle identity remains `com.boxill.eatsoon`.

See [beta walkthrough](NICHE_BETA.md), [release notes](RELEASE_NOTES.md), and [review response draft](V3_REVIEW.md).

Run `flutter analyze` and `flutter test`. Native camera and foreground masks need iOS hardware; simulator tests also exercise normalization, blurry image rejection, file path validation and camera unavailable handling. Five transparent mascot poses are included in `assets/v3/mascot`. Brand fonts include their OFL license.

Visual snapshots are included under `test/goldens`. Their fixture dates make them date-sensitive, so comparison is opt-in: `flutter test test/v3_ui_test.dart --dart-define=V3_COMPARE_GOLDENS=true`. Use `--update-goldens` to deliberately refresh them. Normal tests still verify large-text layout, saved value before the paywall, cancellation, manual setup and restart persistence.
