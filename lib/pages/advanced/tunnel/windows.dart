import 'package:flutter/material.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/tunnel/controller.dart';
import 'package:onexray/pages/advanced/tunnel/widgets.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/theme/theme.dart';
import 'package:onexray/service/connection/policy_editor.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class WindowsVpnPage extends StatefulWidget {
  final PolicyEditorDraft draft;
  final OpenPolicyChild openInterface;
  const WindowsVpnPage({
    super.key,
    required this.draft,
    required this.openInterface,
  });
  @override
  State<WindowsVpnPage> createState() => _WindowsVpnPageState();
}

class _WindowsVpnPageState extends State<WindowsVpnPage> {
  late final controller = PolicyEditorController(draft: widget.draft);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WindowsVpnView(
    controller: controller,
    openInterface: widget.openInterface,
  );
}

class WindowsVpnView extends StatelessWidget {
  const WindowsVpnView({
    super.key,
    required this.controller,
    required this.openInterface,
  });

  final PolicyEditorController controller;
  final OpenPolicyChild openInterface;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context)!;
      final palette = ColorManager.palette(context);
      final mobile =
          MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
      final cidrs = controller.strings('windows', 'excludedCidrs');
      return PolicyDetailScaffold(
        title: l.prototypeWindowsSystemVpn,
        controller: controller,
        canSave: controller.validationHint(l) == null,
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
              l.prototypeSystemVpnPolicy,
              style: AppTypography.platformDetailTitle,
            ),
            Text(
              l.prototypeWindowsBypassNotice,
              style: AppTypography.platformDetailBody,
            ),
            SizedBox(height: mobile ? 12 : 14),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.symmetric(
                  horizontal: BorderSide(color: palette.border),
                ),
              ),
              child: Column(
                children: [
                  _toggle(
                    context,
                    'alwaysOn',
                    l.prototypeAlwaysOn,
                    l.prototypeWindowsAutoConnectNotice,
                  ),
                  Divider(height: 1, thickness: 1, color: palette.border),
                  _toggle(
                    context,
                    'allowLocalNetwork',
                    l.prototypeBypassLocalSubnets,
                    l.prototypeBypassLocalSubnetsHint,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.prototypeBypassNetworks,
                    style: AppTypography.windowsNetworkTitle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '${cidrs.where((value) => value.trim().isNotEmpty).length} / 64',
                  textDirection: TextDirection.ltr,
                  style: AppTypography.windowsNetworkMeta.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l.prototypeBypassNetworksHint,
              style: AppTypography.windowsPolicyHint.copyWith(
                color: palette.mutedForeground,
              ),
            ),
            const SizedBox(height: 16),
            _WindowsNetworks(
              values: cidrs,
              enabled: !controller.blocked,
              onChanged: (values) => controller.update(
                'excludedCidrs',
                values,
                section: 'windows',
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l.prototypeBypassNetworkInputHint,
              style: AppTypography.windowsNetworkNote.copyWith(
                color: palette.mutedForeground,
              ),
            ),
            if (controller.value['ipv6Enabled'] == false) ...[
              const SizedBox(height: 14),
              Text(
                controller.ipv6Conflict
                    ? l.prototypeIpv6BypassConflict
                    : l.prototypeEnableIpv6ForBypass,
                style: AppTypography.windowsNetworkNote.copyWith(
                  color: palette.mutedForeground,
                ),
              ),
            ],
            if ((controller.value['xrayOutboundInterfaceName'] as String)
                .isEmpty) ...[
              const SizedBox(height: 14),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: controller.blocked
                      ? null
                      : () => controller.openChild(context, openInterface),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    textStyle: AppTypography.control,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(l.prototypeChooseInterfaceBeforeSaving),
                ),
              ),
            ],
          ],
        ),
      );
    },
  );

  Widget _toggle(
    BuildContext context,
    String field,
    String title,
    String hint,
  ) {
    final palette = ColorManager.palette(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: AppTypography.platformChoiceTitle),
                const SizedBox(height: 5),
                Text(
                  hint,
                  style: AppTypography.windowsPolicyHint.copyWith(
                    color: palette.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ShadSwitch(
            value: controller.group('windows')[field] as bool,
            onChanged: controller.blocked
                ? null
                : (value) =>
                      controller.update(field, value, section: 'windows'),
          ),
        ],
      ),
    );
  }
}

/// Owns only editing cursors; CIDR validation remains in PolicyEditorService.
class _WindowsNetworks extends StatefulWidget {
  const _WindowsNetworks({
    required this.values,
    required this.enabled,
    required this.onChanged,
  });

  final List<String> values;
  final bool enabled;
  final ValueChanged<List<String>> onChanged;

  @override
  State<_WindowsNetworks> createState() => _WindowsNetworksState();
}

class _WindowsNetworksState extends State<_WindowsNetworks> {
  late final fields = widget.values
      .map((value) => TextEditingController(text: value))
      .toList();
  final _retired = <TextEditingController>[];

  void _publish() =>
      widget.onChanged(fields.map((field) => field.text).toList());

  void _add() {
    setState(() => fields.add(TextEditingController()));
    _publish();
  }

  void _remove(int index) {
    setState(() => _retired.add(fields.removeAt(index)));
    _publish();
  }

  @override
  void dispose() {
    for (final field in [...fields, ..._retired]) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < fields.length; index++) ...[
          Focus(
            key: ObjectKey(fields[index]),
            child: Builder(
              builder: (context) => Container(
                key: ValueKey('windows-cidr-row:$index'),
                constraints: const BoxConstraints(minHeight: 50),
                padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 8, 4),
                decoration: BoxDecoration(
                  color: palette.card,
                  border: Border.all(
                    color: Focus.of(context).hasFocus
                        ? palette.primary
                        : palette.border,
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.network,
                      size: 18,
                      color: palette.mutedForeground,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        label: l.prototypeBypassNetworkNumber(index + 1),
                        child: TextField(
                          controller: fields[index],
                          enabled: widget.enabled,
                          autocorrect: false,
                          enableSuggestions: false,
                          textDirection: TextDirection.ltr,
                          style: AppTypography.windowsNetworkInput,
                          decoration: const InputDecoration(
                            hintText: '192.168.1.0/24',
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 8),
                          ),
                          onChanged: (_) => _publish(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      tooltip: l.prototypeRemoveBypassNetworkNumber(index + 1),
                      onPressed: widget.enabled ? () => _remove(index) : null,
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(36),
                        maximumSize: const Size.square(36),
                        padding: EdgeInsets.zero,
                        foregroundColor: palette.mutedStrong,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(LucideIcons.trash2, size: 17),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (fields.isEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
            decoration: ShapeDecoration(
              shape: AppDashedBorder(
                borderRadius: BorderRadius.circular(AppRadii.control),
                side: BorderSide(color: palette.border),
              ),
            ),
            child: Text(
              l.prototypeNoBypassNetworks,
              textAlign: TextAlign.center,
              style: AppTypography.windowsNetworkMeta.copyWith(
                color: palette.mutedForeground,
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        OutlinedButton(
          onPressed: widget.enabled && fields.length < 64 ? _add : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.plus, size: 16),
              const SizedBox(width: 8),
              Text(l.prototypeAddNetwork),
            ],
          ),
        ),
      ],
    );
  }
}
