import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/dialogs.dart';
import 'package:onexray/pages/servers/editor/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/widget/adaptive_dialog.dart';
import 'package:onexray/pages/widget/outbound_json_editor.dart';

class ServerEditorPage extends StatelessWidget {
  final int serverId;
  const ServerEditorPage({super.key, required this.serverId});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => ServerEditorController(serverId)..load(context),
    child: BlocBuilder<ServerEditorController, ServerEditorPageState>(
      builder: (context, state) {
        final controller = context.read<ServerEditorController>();
        final l = AppLocalizations.of(context)!;
        final p = ColorManager.palette(context);
        final mobile =
            MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
        return PopScope(
          canPop: !state.busy,
          child: AppDialog(
            title: l.prototypeEditServer,
            subtitle: state.name,
            onClose: () => controller.closePage(context),
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
                    state.fromSubscription
                        ? l.prototypeSubscriptionOutboundHint
                        : l.prototypeOutboundJsonHint,
                    style: AppTypography.importJsonHint.copyWith(
                      color: p.mutedForeground,
                    ),
                  ),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          state.error!,
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
                onPressed: state.busy
                    ? null
                    : () => controller.closePage(context),
              ),
              ConnectDialogButton(
                label: l.prototypeSave,
                busy: state.busy,
                onPressed: state.busy || !state.loaded || !state.validJson
                    ? null
                    : () => controller.save(context),
              ),
            ],
          ),
        );
      },
    ),
  );
}
