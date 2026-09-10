import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/shared/alert.dart';
import 'package:onexray/pages/shared/page_cubit.dart';
import 'package:onexray/service/shared/failure.dart';
import 'package:onexray/service/shared/share/outgoing_share.dart';

typedef ShareTextBuilder = FutureOr<ShareText> Function();
typedef ShareActionView = ({
  String label,
  IconData icon,
  bool busy,
  VoidCallback? onPressed,
});

/// Adds sharing behavior to an existing button without changing its style.
class ShareAction extends StatelessWidget {
  const ShareAction({
    super.key,
    required this.prepare,
    required this.builder,
    this.enabled = true,
    this.warning,
    this.copiedMessage,
    this.outgoing,
  });

  final ShareTextBuilder prepare;
  final Widget Function(BuildContext, ShareActionView) builder;
  final bool enabled;
  final String? warning;
  final String? copiedMessage;
  final OutgoingShare? outgoing;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => ShareActionCubit(outgoing ?? OutgoingShare()),
    child: BlocBuilder<ShareActionCubit, bool>(
      builder: (context, busy) {
        final cubit = context.read<ShareActionCubit>();
        final l = AppLocalizations.of(context)!;
        final copy = cubit.outgoing.destination == ShareDestination.clipboard;
        return Builder(
          builder: (buttonContext) => builder(buttonContext, (
            label: copy ? l.sharePageCopyLink : l.prototypeShare,
            icon: copy ? LucideIcons.copy : LucideIcons.share2,
            busy: busy,
            onPressed: enabled && !busy
                ? () => cubit.run(
                    buttonContext,
                    prepare: prepare,
                    warning: warning,
                    copiedMessage: copiedMessage,
                  )
                : null,
          )),
        );
      },
    ),
  );
}

/// A pending native operation belongs to this action, never to a global queue.
class ShareActionCubit extends PageCubit<bool> {
  ShareActionCubit(this.outgoing) : super(false);

  final OutgoingShare outgoing;

  Future<void> run(
    BuildContext context, {
    required ShareTextBuilder prepare,
    String? warning,
    String? copiedMessage,
  }) async {
    if (state || !context.mounted || !_canUse(context)) return;
    emit(true);
    final copy = outgoing.destination == ShareDestination.clipboard;
    try {
      final content = await prepare();
      if (!context.mounted || !_canUse(context)) return;
      if (warning != null) {
        final l = AppLocalizations.of(context)!;
        final label = copy ? l.sharePageCopyLink : l.prototypeShare;
        final confirmed = await ContextAlert.showConfirmDialog(
          context,
          title: label,
          content: warning,
          confirmLabel: label,
        );
        if (!confirmed || !context.mounted || !_canUse(context)) return;
      }
      await outgoing.sendText(content, origin: _origin(context));
      if (copy && context.mounted && _canUse(context)) {
        final l = AppLocalizations.of(context)!;
        ContextAlert.showToast(
          context,
          copiedMessage ?? l.actionResult(l.sharePageCopyLink, l.resultSuccess),
        );
      }
    } catch (error) {
      if (context.mounted && _canUse(context)) {
        final l = AppLocalizations.of(context)!;
        ContextAlert.showToast(
          context,
          appFailureMessage(
            l,
            error,
            operation: l.actionResult(
              copy ? l.sharePageCopyLink : l.prototypeShare,
              l.resultFailed,
            ),
          ),
        );
      }
    } finally {
      emit(false);
    }
  }

  bool _canUse(BuildContext context) =>
      isPageActive &&
      TickerMode.valuesOf(context).enabled &&
      (ModalRoute.of(context)?.isCurrent ?? true);

  static Rect? _origin(BuildContext context) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    return rect.isFinite && !rect.isEmpty ? rect : null;
  }
}
