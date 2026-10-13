# EatSoon

Review items extracted from a fridge photo, confirm label dates or suggested check intervals, then log used items.

Version 3.0.0 (3013), Flutter for iPhone. Production entrypoint: `lib/main.dart`; dashboard and domain logic: `lib/v3`. Bundle identity remains `com.boxill.eatsoon`.

See [beta walkthrough](NICHE_BETA.md), [release notes](RELEASE_NOTES.md), and [review response draft](V3_REVIEW.md).

Run `flutter analyze` and `flutter test`. Native camera and foreground masks need iOS hardware; simulator tests also exercise normalization, blurry image rejection, file path validation and camera unavailable handling. Five transparent mascot poses are included in `assets/v3/mascot`. Brand fonts include their OFL license.
