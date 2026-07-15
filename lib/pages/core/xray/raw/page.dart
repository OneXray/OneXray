import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/raw/controller.dart';
import 'package:onexray/pages/core/xray/raw/params.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/event_bus/service.dart';
import 'package:onexray/service/event_bus/state.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class XrayRawPage extends StatelessWidget {
  final XrayRawParams params;

  const XrayRawPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => XrayRawController(params),
      child: BlocBuilder<XrayRawController, XrayRawPageState>(
        builder: (context, state) {
          final controller = context.read<XrayRawController>();
          return SettingsPageScaffold(
            title: AppLocalizations.of(context)!.xrayRawPageTitle,
            actions: [
              AppMenuButton<IconMenuId>(
                icon: LucideIcons.upload,
                entries: iconMenuEntries([
                  IconMenuId.pickFile,
                  IconMenuId.readPasteboard,
                ]),
                onSelected: (menuId) =>
                    controller.importAction(context, menuId),
              ),
            ],
            body: _body(context, controller, state),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    XrayRawController controller,
    XrayRawPageState state,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
            child: ResponsiveContent(
              desktopMaxWidth: 900,
              adaptiveBreakpoint: 840,
              child: SettingsJsonEditor(
                controller: controller.controller,
                lineCount: state.lineCount,
                valid: state.validJson,
                validLabel: l10n.jsonEditorValid,
                invalidLabel: l10n.jsonEditorInvalid,
                linesLabel: "${state.lineCount} ${l10n.jsonEditorLines}",
                spacesLabel: l10n.jsonEditorSpaces,
              ),
            ),
          ),
        ),
        SettingsPageActionBar(
          children: [
            BlocBuilder<AppEventBus, AppEventBusState>(
              bloc: AppEventBus.instance,
              builder: (context, eventState) {
                final pinging = eventState.pinging;
                return ShadButton.outline(
                  leading: pinging
                      ? const SizedBox.square(
                          dimension: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(LucideIcons.gauge, size: 16),
                  onPressed: pinging
                      ? null
                      : () => controller.realPing(context),
                  child: Text(l10n.outboundPageRealPing),
                );
              },
            ),
            const SizedBox(width: 8),
            ShadButton(
              leading: const Icon(LucideIcons.save, size: 16),
              onPressed: () => controller.save(context),
              child: Text(l10n.buttonSave),
            ),
          ],
        ),
      ],
    );
  }
}
