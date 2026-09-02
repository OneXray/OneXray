import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/raw_editor/controller.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RawEditorPage extends StatefulWidget {
  final int? rawId;
  final String? initialText;
  final String? initialName;
  const RawEditorPage({
    super.key,
    this.rawId,
    this.initialText,
    this.initialName,
  });
  @override
  State<RawEditorPage> createState() => _RawEditorPageState();
}

class _RawEditorPageState extends State<RawEditorPage> {
  late final controller = RawEditorController(
    rawId: widget.rawId,
    initialText: widget.initialText,
    initialName: widget.initialName,
  );
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
      final l10n = AppLocalizations.of(context)!;
      return PopScope(
        canPop: !controller.busy,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.rawId == null
                  ? l10n.prototypeAddRawJson
                  : l10n.prototypeEditRawJson,
            ),
            leading: BackButton(onPressed: () => controller.closePage(context)),
            actions: [
              IconButton(
                tooltip: l10n.prototypeReadClipboard,
                onPressed: controller.busy
                    ? null
                    : () => controller.importText(context, clipboard: true),
                icon: const Icon(LucideIcons.clipboardPaste),
              ),
              IconButton(
                tooltip: l10n.prototypeImportFile,
                onPressed: controller.busy
                    ? null
                    : () => controller.importText(context, clipboard: false),
                icon: const Icon(LucideIcons.fileInput),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ResponsiveContent(
                desktopMaxWidth: 1000,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.prototypeRawManagedSettingsNotice,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller.name,
                      maxLength: 32,
                      enabled: !controller.busy && controller.loaded,
                      decoration: InputDecoration(
                        labelText: l10n.prototypeConfigurationName,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: AbsorbPointer(
                        absorbing: controller.busy || !controller.loaded,
                        child: SettingsJsonEditor(
                          controller: controller.text,
                          lineCount: controller.lineCount,
                          valid: controller.validJson,
                          validLabel: l10n.jsonEditorValid,
                          invalidLabel: l10n.jsonEditorInvalid,
                          linesLabel:
                              '${controller.lineCount} ${l10n.jsonEditorLines}',
                          spacesLabel: l10n.jsonEditorSpaces,
                        ),
                      ),
                    ),
                    if (controller.busy) const LinearProgressIndicator(),
                    if (controller.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            controller.error!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: PageActionBar(
            children: [
              ShadButton.outline(
                onPressed: controller.busy
                    ? null
                    : () => controller.closePage(context),
                child: Text(l10n.prototypeCancel),
              ),
              ShadButton(
                onPressed: controller.busy || !controller.loaded
                    ? null
                    : () => controller.save(context),
                child: Text(l10n.prototypeSave),
              ),
            ],
          ),
        ),
      );
    },
  );
}
