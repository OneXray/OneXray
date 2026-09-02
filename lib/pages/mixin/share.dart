import 'package:flutter/material.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:share_plus/share_plus.dart';

/// How far the platform share sheet got, as far as the platform can tell.
enum ShareOutcome {
  /// The platform confirmed the user completed the share.
  success,

  /// The user dismissed the sheet, or the platform cannot report an outcome.
  /// Windows always lands here, even after its share flyout opened, so this
  /// outcome must never be reported to the user as a failure.
  unconfirmed,

  /// The platform rejected the share.
  failed,
}

/// Shared plumbing for the platform share sheet.
class ContextShare {
  /// The anchor rect iPad and macOS need to place the share popover.
  ///
  /// Returns null when [context] cannot supply one. A context taken from a
  /// sliver `itemBuilder` is the common case: it belongs to the sliver element,
  /// so its render object is a [RenderSliver] instead of a [RenderBox]. Rows
  /// that want a row-sized anchor have to wrap themselves in a [Builder] and
  /// pass that context on to their callbacks.
  static Rect? positionOrigin(BuildContext context) {
    if (!context.mounted) {
      return null;
    }
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }
    return renderObject.localToGlobal(Offset.zero) & renderObject.size;
  }

  /// Opens the platform share sheet and classifies the outcome.
  ///
  /// Channel errors are logged and reported as [ShareOutcome.failed] instead of
  /// escaping as an unhandled asynchronous error. Nothing about [params] is
  /// logged, because shared text can carry node credentials.
  static Future<ShareOutcome> share(ShareParams params) async {
    try {
      final result = await SharePlus.instance.share(params);
      return result.status == ShareResultStatus.success
          ? ShareOutcome.success
          : ShareOutcome.unconfirmed;
    } catch (e, stackTrace) {
      ygLogger("share sheet failed: $e\n$stackTrace");
      return ShareOutcome.failed;
    }
  }
}
