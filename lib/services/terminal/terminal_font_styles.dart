import 'package:flutter/painting.dart';
import 'package:google_fonts/google_fonts.dart';

/// ターミナル用等幅フォントスタイル
///
/// Google Fontsの等幅フォントを統一的に取得する。
class TerminalFontStyles {
  TerminalFontStyles._();

  /// サポートするフォントファミリーのリスト
  static const List<String> supportedFontFamilies = [
    'JetBrains Mono',
    'Fira Code',
    'Source Code Pro',
    'Roboto Mono',
    'Ubuntu Mono',
    'Inconsolata',
  ];

  /// デフォルトのフォントファミリー
  static const String defaultFontFamily = 'JetBrains Mono';

  /// フォントファミリー名からGoogle FontsのTextStyleを取得
  ///
  /// [fontFamily] フォントファミリー名
  /// [fontSize] フォントサイズ
  /// [height] 行の高さ比率
  /// [color] 文字色
  /// [backgroundColor] 背景色
  /// [fontWeight] フォントウェイト
  /// [fontStyle] フォントスタイル（イタリック等）
  /// [decoration] テキスト装飾（下線、取り消し線等）
  static TextStyle getTextStyle(
    String fontFamily, {
    double? fontSize,
    double? height,
    Color? color,
    Color? backgroundColor,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    TextDecoration? decoration,
  }) {
    switch (fontFamily) {
      case 'JetBrains Mono':
        return GoogleFonts.jetBrainsMono(
          fontSize: fontSize,
          height: height,
          color: color,
          backgroundColor: backgroundColor,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          decoration: decoration,
        );
      case 'Fira Code':
        return GoogleFonts.firaCode(
          fontSize: fontSize,
          height: height,
          color: color,
          backgroundColor: backgroundColor,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          decoration: decoration,
        );
      case 'Source Code Pro':
        return GoogleFonts.sourceCodePro(
          fontSize: fontSize,
          height: height,
          color: color,
          backgroundColor: backgroundColor,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          decoration: decoration,
        );
      case 'Roboto Mono':
        return GoogleFonts.robotoMono(
          fontSize: fontSize,
          height: height,
          color: color,
          backgroundColor: backgroundColor,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          decoration: decoration,
        );
      case 'Ubuntu Mono':
        return GoogleFonts.ubuntuMono(
          fontSize: fontSize,
          height: height,
          color: color,
          backgroundColor: backgroundColor,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          decoration: decoration,
        );
      case 'Inconsolata':
        return GoogleFonts.inconsolata(
          fontSize: fontSize,
          height: height,
          color: color,
          backgroundColor: backgroundColor,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          decoration: decoration,
        );
      default:
        // デフォルトはJetBrains Mono
        return GoogleFonts.jetBrainsMono(
          fontSize: fontSize,
          height: height,
          color: color,
          backgroundColor: backgroundColor,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          decoration: decoration,
        );
    }
  }
}
