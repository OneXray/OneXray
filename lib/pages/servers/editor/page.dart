import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/dialogs.dart';
import 'package:onexray/pages/servers/editor/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/widget/adaptive_dialog.dart';
import 'package:onexray/pages/widget/outbound_json_editor.dart';

class ServerEditorPage extends StatefulWidget {
  final int serverId;
  const ServerEditorPage({super.key, required this.serverId});
  @override
  State<ServerEditorPage> createState() => _ServerEditorPageState();
}

class _ServerEditorPageState extends State<ServerEditorPage> {
  late final controller = ServerEditorController(widget.serverId);
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      controller.load(context);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context)!;
      final p = ColorManager.palette(context);
      final mobile =
          MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
      return PopScope(
        canPop: !controller.busy,
        child: AppDialog(
          title: l.prototypeEditServer,
          subtitle: controller.name,
          onClose: () => controller.close(context),
          body: Padding(
            padding: EdgeInsets.fromLTRB(
              mobile ? 16 : 20,
              20,
              mobile ? 16 : 20,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.prototypeXrayOutboundJson,
                  style: AppTypography.subscriptionField.copyWith(
                    color: p.mutedStrong,
                  ),
                ),
                const SizedBox(height: 7),
                OutboundJsonEditor(controller: controller.text),
                const SizedBox(height: 7),
                Text(
                  controller.fromSubscription
                      ? l.prototypeSubscriptionOutboundHint
                      : l.prototypeOutboundJsonHint,
                  style: AppTypography.importJsonHint.copyWith(
                    color: p.mutedForeground,
                  ),
                ),
                if (controller.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        controller.error!,
                        style: AppTypography.subscriptionInfo.copyWith(
                          color: p.destructive,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            ConnectDialogButton(
              label: l.prototypeCancel,
              secondary: true,
              onPressed: controller.busy
                  ? null
                  : () => controller.close(context),
            ),
            ConnectDialogButton(
              label: l.prototypeSave,
              busy: controller.busy,
              onPressed:
                  controller.busy || !controller.loaded || !controller.validJson
                  ? null
                  : () => controller.save(context),
            ),
          ],
        ),
      );
    },
  );
}
