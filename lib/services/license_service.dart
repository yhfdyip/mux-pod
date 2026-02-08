import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// フォントライセンスを登録するサービス
class LicenseService {
  static bool _initialized = false;

  /// ライセンスを登録する（一度だけ実行）
  static void registerLicenses() {
    if (_initialized) return;
    _initialized = true;

    LicenseRegistry.addLicense(() async* {
      final hackgenLicense =
          await rootBundle.loadString('assets/fonts/HackGenConsole-LICENSE.txt');
      yield LicenseEntryWithLineBreaks(['HackGen Console'], hackgenLicense);

      final udevLicense =
          await rootBundle.loadString('assets/fonts/UDEVGothicNF-LICENSE.txt');
      yield LicenseEntryWithLineBreaks(['UDEV Gothic NF'], udevLicense);
    });
  }
}
