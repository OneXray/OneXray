import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/tunnel/controller.dart';
import 'package:onexray/pages/advanced/tunnel/widgets.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/connection/policy_editor.dart';
import 'package:onexray/service/launch/setup.dart';

class OutboundInterfaceController extends PolicyEditorController {
  List<SetupInterface> interfaces = [];
  bool loading = true;
  bool failed = false;
  bool _disposed = false;
  OutboundInterfaceController({required PolicyEditorDraft draft})
    : super(draft: draft);

  Future<void> readInterfaces() async {
    loading = true;
    failed = false;
    notify();
    try {
      final values = await SetupService(platform: platform).interfaces();
      if (!_disposed) {
        interfaces = values;
      }
    } catch (_) {
      failed = true;
    } finally {
      loading = false;
      notify();
    }
  }

  String description(SetupInterface value, AppLocalizations l) => [
    if (value.currentInternet) l.prototypeCurrentInternetInterface,
    ...value.addresses,
  ].join('\n');

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class OutboundInterfacePage extends StatefulWidget {
  final PolicyEditorDraft draft;
  const OutboundInterfacePage({super.key, required this.draft});
  @override
  State<OutboundInterfacePage> createState() => _OutboundInterfacePageState();
}

class _OutboundInterfacePageState extends State<OutboundInterfacePage> {
  late final controller = OutboundInterfaceController(draft: widget.draft)
    ..readInterfaces();
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
      return PolicyDetailScaffold(
        title: l.prototypeXrayOutboundInterface,
        controller: controller,
        canSave:
            !controller.loading &&
            !controller.failed &&
            (controller.value['xrayOutboundInterfaceName'] as String)
                .isNotEmpty,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.prototypeInterfaceSelectionNotice),
            ),
            if (controller.loading)
              const Center(child: CircularProgressIndicator())
            else if (controller.failed || controller.interfaces.isEmpty)
              Column(
                children: [
                  Text(l.prototypeTemporarilyUnavailable),
                  TextButton(
                    onPressed: controller.readInterfaces,
                    child: Text(l.prototypeRetry),
                  ),
                ],
              )
            else
              for (final value in controller.interfaces)
                SettingsChoiceRow(
                  title: value.name,
                  description: controller.description(value, l),
                  selected:
                      controller.value['xrayOutboundInterfaceName'] ==
                      value.name,
                  onTap: controller.blocked
                      ? null
                      : () => controller.update(
                          'xrayOutboundInterfaceName',
                          value.name,
                        ),
                ),
          ],
        ),
      );
    },
  );
}
