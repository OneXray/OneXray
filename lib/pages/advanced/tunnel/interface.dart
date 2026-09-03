import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/tunnel/controller.dart';
import 'package:onexray/pages/advanced/tunnel/widgets.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/service/connection/policy_editor.dart';
import 'package:onexray/service/launch/setup.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class OutboundInterfaceController extends PolicyEditorController {
  List<SetupInterface> interfaces = [];
  bool loading = true;
  bool failed = false;
  bool _disposed = false;
  OutboundInterfaceController({required PolicyEditorDraft draft, super.service})
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
  Widget build(BuildContext context) =>
      OutboundInterfaceView(controller: controller);
}

class OutboundInterfaceView extends StatelessWidget {
  const OutboundInterfaceView({
    super.key,
    required this.controller,
    this.onRetry,
  });

  final OutboundInterfaceController controller;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context)!;
      final palette = ColorManager.palette(context);
      final mobile =
          MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
      final selected = controller.value['xrayOutboundInterfaceName'] as String;
      return PolicyDetailScaffold(
        title: l.prototypeXrayOutboundInterface,
        controller: controller,
        canSave:
            !controller.loading && !controller.failed && selected.isNotEmpty,
        contentPadding: EdgeInsets.fromLTRB(
          mobile ? 14 : 28,
          mobile ? 12 : 18,
          mobile ? 14 : 28,
          mobile ? 18 : 24,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.prototypeChooseInterface,
              style: AppTypography.platformDetailTitle,
            ),
            Text(
              l.prototypeInterfaceSelectionNotice,
              style: AppTypography.platformDetailBody,
            ),
            SizedBox(height: mobile ? 12 : 14),
            if (controller.loading)
              const Center(child: CircularProgressIndicator())
            else if (controller.failed || controller.interfaces.isEmpty)
              Column(
                children: [
                  Text(l.prototypeTemporarilyUnavailable),
                  TextButton(
                    onPressed: onRetry ?? controller.readInterfaces,
                    child: Text(l.prototypeRetry),
                  ),
                ],
              )
            else
              ShadRadioGroup<String>(
                initialValue: selected,
                enabled: !controller.blocked,
                axis: Axis.horizontal,
                onChanged: (value) {
                  if (value != null && value != selected) {
                    controller.update('xrayOutboundInterfaceName', value);
                  }
                },
                items: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: palette.border)),
                    ),
                    child: Column(
                      children: [
                        for (final value in controller.interfaces)
                          _InterfaceRow(
                            value: value,
                            selected: selected == value.name,
                            enabled: !controller.blocked,
                            onTap: () => controller.update(
                              'xrayOutboundInterfaceName',
                              value.name,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            Container(
              constraints: BoxConstraints(minHeight: mobile ? 50 : 49),
              padding: EdgeInsets.symmetric(
                horizontal: mobile ? 10 : 16,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.info, size: 16, color: palette.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.prototypeManagedInterfaceNotice,
                      style:
                          (mobile
                                  ? AppTypography.runtimeCodeNote
                                  : AppTypography.runtimeCodeDesktopNote)
                              .copyWith(color: palette.mutedForeground),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _InterfaceRow extends StatelessWidget {
  const _InterfaceRow({
    required this.value,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final SetupInterface value;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return MergeSemantics(
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        child: Material(
          color: selected ? palette.selectedSurface : palette.card,
          child: InkWell(
            onTap: enabled ? onTap : null,
            child: Container(
              constraints: const BoxConstraints(minHeight: 68),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: palette.border)),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(5, 4, 3, 0),
                    child: SizedBox.square(
                      dimension: 17,
                      child: ShadRadio<String>(
                        value: value.name,
                        enabled: enabled,
                        size: 15,
                        circleSize: 9,
                        radioPadding: EdgeInsets.zero,
                        decoration: ShadDecoration(
                          border: ShadBorder.all(
                            color: selected
                                ? palette.primary
                                : palette.mutedForeground,
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          value.name,
                          style: AppTypography.platformChoiceTitle,
                        ),
                        if (value.currentInternet) ...[
                          const SizedBox(height: 4),
                          Text(
                            l.prototypeCurrentInternetInterface,
                            style: AppTypography.platformChoiceHint.copyWith(
                              color: palette.primary,
                            ),
                          ),
                        ],
                        if (value.addresses.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            value.addresses.join('\n'),
                            textDirection: TextDirection.ltr,
                            style: AppTypography.platformChoiceHint.copyWith(
                              color: palette.mutedForeground,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
