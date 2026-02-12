/// ビルド時に注入されるバージョン情報を提供する。
///
/// 優先順位:
/// 1. APP_VERSION (CIがリリースタグから設定)
/// 2. GIT_REF (ブランチ名@コミットハッシュ)
/// 3. 'UNKNOWN'
class VersionInfo {
  static const String _appVersion = String.fromEnvironment('APP_VERSION');
  static const String _gitRef = String.fromEnvironment('GIT_REF');

  static String get version {
    if (_appVersion.isNotEmpty) return _appVersion;
    if (_gitRef.isNotEmpty) return _gitRef;
    return 'UNKNOWN';
  }
}
