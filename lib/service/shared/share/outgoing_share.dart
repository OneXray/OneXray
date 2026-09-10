import 'package:flutter/services.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:share_plus/share_plus.dart';

enum ShareDestination { system, clipboard }

class ShareText {
  const ShareText({required this.title, required this.text});

  final String title;
  final String text;
}

/// Dispatches prepared links without interpreting native results as delivery.
class OutgoingShare {
  OutgoingShare({
    ShareDestination? destination,
    SharePlus? platform,
    Future<void> Function(String)? writeClipboard,
  }) : destination =
           destination ??
           (AppPlatform.isLinux
               ? ShareDestination.clipboard
               : ShareDestination.system),
       _platform = platform ?? SharePlus.instance,
       _writeClipboard = writeClipboard ?? _copyText;

  final ShareDestination destination;
  final SharePlus _platform;
  final Future<void> Function(String) _writeClipboard;

  Future<void> sendText(ShareText content, {Rect? origin}) async {
    if (content.text.isEmpty) {
      throw ArgumentError('Share text must not be empty');
    }
    if (destination == ShareDestination.clipboard) {
      await _writeClipboard(content.text);
      return;
    }
    final title = content.title.trim();
    final metadata = title.isEmpty ? 'OneXray' : title;
    // None of the three native statuses guarantees delivery or warrants a
    // clipboard fallback. Invocation errors propagate with their original cause.
    await _platform.share(
      ShareParams(
        text: content.text,
        title: metadata,
        subject: metadata,
        sharePositionOrigin: origin,
      ),
    );
  }

  static Future<void> _copyText(String text) =>
      Clipboard.setData(ClipboardData(text: text));
}
