import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/xray/raw_edit/controller.dart';
import 'package:onexray/pages/core/xray/raw_edit/params.dart';
import 'package:onexray/pages/widget/menu_picker.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class XrayRawEditPage extends StatelessWidget {
  final XrayRawEditParams params;

  const XrayRawEditPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => XrayRawEditController(params),
      child: BlocBuilder<XrayRawEditController, XrayRawEditPageState>(
        builder: (context, state) {
          final controller = context.read<XrayRawEditController>();
          return SettingsPageScaffold(
            title: params.title,
            onSave: () => controller.save(context),
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
    XrayRawEditController controller,
    XrayRawEditPageState state,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
      child: ResponsiveContent(
        desktopMaxWidth: 900,
        adaptiveBreakpoint: 840,
        child: SettingsCodeEditor(
          controller: controller.controller,
          valid: state.validJson,
          validLabel: l10n.jsonEditorValid,
          invalidLabel: l10n.jsonEditorInvalid,
          linesLabel: "${state.lineCount} ${l10n.jsonEditorLines}",
          spacesLabel: l10n.jsonEditorSpaces,
        ),
      ),
    );
  }
}
