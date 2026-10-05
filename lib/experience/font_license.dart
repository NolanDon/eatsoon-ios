import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

void registerBrandFontLicense() {
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(["DM Sans"], license);
  });
}
