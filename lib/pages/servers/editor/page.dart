import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/servers/editor/controller.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

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
      return PopScope(
        canPop: !controller.busy,
        child: Scaffold(
          appBar: AppBar(
            title: Text(l.prototypeEditServer),
            leading: BackButton(onPressed: () => controller.close(context)),
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ResponsiveContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l.prototypeXrayOutboundJson,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.fromSubscription
                          ? l.prototypeSubscriptionOutboundHint
                          : l.prototypeOutboundJsonHint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: AbsorbPointer(
                        absorbing: controller.busy || !controller.loaded,
                        child: SettingsJsonEditor(
                          controller: controller.text,
                          lineCount: controller.lineCount,
                          valid: controller.validJson,
                          validLabel: l.jsonEditorValid,
                          invalidLabel: l.jsonEditorInvalid,
                          linesLabel:
                              '${controller.lineCount} ${l.jsonEditorLines}',
                          spacesLabel: l.jsonEditorSpaces,
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
                    : () => controller.close(context),
                child: Text(l.prototypeCancel),
              ),
              ShadButton(
                onPressed: controller.busy || !controller.loaded
                    ? null
                    : () => controller.save(context),
                child: Text(l.prototypeSave),
              ),
            ],
          ),
        ),
      );
    },
  );
}
