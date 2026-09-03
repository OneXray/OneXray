import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/core/model/geo_data_type.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/geodata/controller.dart';
import 'package:onexray/pages/advanced/geodata/view.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadInput;

class GeoDataPage extends StatefulWidget {
  const GeoDataPage({super.key, required this.openFile});
  final void Function(BuildContext, int) openFile;
  @override
  State<GeoDataPage> createState() => _GeoDataPageState();
}

class _GeoDataPageState extends State<GeoDataPage> {
  final controller = GeoDataController();
  final scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    controller.initialize();
  }

  @override
  void dispose() {
    scroll.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final l = AppLocalizations.of(context)!;
      final mobile =
          MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
      final palette = ColorManager.palette(context);
      return Scaffold(
        appBar: AppBar(title: Text(l.prototypeRoutingData)),
        body: SafeArea(
          child: ResponsiveContent(
            child: controller.loading
                ? const Center(child: CircularProgressIndicator())
                : controller.failed
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l.prototypeRoutingFileUnavailable),
                        TextButton(
                          onPressed: controller.initialize,
                          child: Text(l.prototypeRetry),
                        ),
                      ],
                    ),
                  )
                : Scrollbar(
                    controller: scroll,
                    child: ListView(
                      controller: scroll,
                      padding: mobile
                          ? const EdgeInsets.fromLTRB(14, 10, 14, 18)
                          : const EdgeInsets.all(20),
                      children: [
                        Text(
                          l.prototypeRoutingDataHint,
                          style: mobile
                              ? AppTypography.geodataIntro.copyWith(
                                  color: palette.mutedForeground,
                                )
                              : null,
                        ),
                        SizedBox(height: mobile ? 10 : 12),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: SizedBox(
                            width: mobile ? double.infinity : null,
                            child: FilledButton.icon(
                              style: mobile
                                  ? FilledButton.styleFrom(
                                      minimumSize: const Size(0, 38),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                      ),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      textStyle:
                                          AppTypography.geodataPrimaryAction,
                                      visualDensity: VisualDensity.standard,
                                    )
                                  : null,
                              onPressed: controller.busy
                                  ? null
                                  : () => controller.updateAll(context),
                              icon: const Icon(LucideIcons.refreshCw, size: 15),
                              label: Text(l.prototypeUpdateAll),
                            ),
                          ),
                        ),
                        SizedBox(height: mobile ? 5 : 8),
                        Text(
                          l.prototypeHttpsOnly,
                          textAlign: mobile ? TextAlign.center : TextAlign.end,
                          style: mobile
                              ? AppTypography.geodataValue.copyWith(
                                  color: palette.mutedForeground,
                                )
                              : Theme.of(context).textTheme.bodySmall,
                        ),
                        if (controller.busy)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: LinearProgressIndicator(),
                          ),
                        SizedBox(height: mobile ? 7 : 28),
                        _heading(
                          context,
                          l.prototypeDefaultRoutingData,
                          OutlinedButton.icon(
                            style: _headingButtonStyle(context),
                            onPressed: controller.busy
                                ? null
                                : () => controller.update(context, null),
                            icon: const Icon(LucideIcons.refreshCw, size: 16),
                            label: Text(l.prototypeUpdate),
                          ),
                        ),
                        GeoDataRows(
                          files: controller.defaults,
                          custom: false,
                          busy: controller.busy,
                          onOpen: (file) =>
                              widget.openFile(context, file.row.id),
                          onUpdate: (file) => controller.update(context, file),
                          onDelete: (file) => controller.delete(context, file),
                        ),
                        if (controller.errors[-1] != null)
                          _error(context, controller.errors[-1]!),
                        SizedBox(height: mobile ? 18 : 28),
                        _heading(
                          context,
                          l.prototypeCustomRoutingData,
                          OutlinedButton.icon(
                            style: _headingButtonStyle(context),
                            onPressed: controller.busy
                                ? null
                                : controller.toggleAdd,
                            icon: const Icon(LucideIcons.plus, size: 16),
                            label: Text(l.prototypeAddDataSource),
                          ),
                        ),
                        if (controller.adding) _form(context),
                        if (controller.custom.isEmpty)
                          Container(
                            constraints: const BoxConstraints(minHeight: 72),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: palette.border),
                                bottom: BorderSide(color: palette.border),
                              ),
                            ),
                            child: Text(
                              l.prototypeNoCustomRoutingData,
                              textAlign: TextAlign.center,
                              style: AppTypography.settingsDetailNote.copyWith(
                                color: palette.mutedForeground,
                              ),
                            ),
                          )
                        else
                          GeoDataRows(
                            files: controller.custom,
                            custom: true,
                            busy: controller.busy,
                            onOpen: (file) =>
                                widget.openFile(context, file.row.id),
                            onUpdate: (file) =>
                                controller.update(context, file),
                            onDelete: (file) =>
                                controller.delete(context, file),
                          ),
                        for (final file in controller.custom)
                          if (controller.errors[file.row.id] != null)
                            _error(
                              context,
                              '${file.fileName}: ${controller.errors[file.row.id]}',
                            ),
                      ],
                    ),
                  ),
          ),
        ),
      );
    },
  );

  ButtonStyle? _headingButtonStyle(BuildContext context) =>
      MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint
      ? OutlinedButton.styleFrom(
          minimumSize: const Size(0, 34),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          textStyle: AppTypography.geodataAction,
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        )
      : null;

  Widget _heading(BuildContext context, String title, Widget action) =>
      Container(
        constraints: const BoxConstraints(minHeight: 42),
        padding: MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint
            ? EdgeInsets.zero
            : const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style:
                    MediaQuery.sizeOf(context).width <=
                        AppLayout.mobileBreakpoint
                    ? AppTypography.geodataTitle
                    : Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 12),
            action,
          ],
        ),
      );

  Widget _error(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: Theme.of(context).colorScheme.error),
    ),
  );

  Widget _form(BuildContext context) {
    if (MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint) {
      return _mobileForm(context);
    }
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<GeoDataType>(
            initialValue: controller.type,
            decoration: InputDecoration(labelText: l.prototypeDataType),
            items: const [
              DropdownMenuItem(value: GeoDataType.ip, child: Text('GeoIP')),
              DropdownMenuItem(
                value: GeoDataType.domain,
                child: Text('GeoSite'),
              ),
            ],
            onChanged: controller.busy ? null : controller.changeType,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller.name,
            enabled: !controller.busy,
            autocorrect: false,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: l.prototypeSavedFileName),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: controller.url,
            enabled: !controller.busy,
            keyboardType: TextInputType.url,
            autocorrect: false,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: l.prototypeHttpsDownloadAddress,
            ),
          ),
          if (controller.formError != null)
            _error(context, controller.formError!),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 12,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: controller.busy ? null : controller.toggleAdd,
                child: Text(l.prototypeCancel),
              ),
              FilledButton(
                onPressed: controller.busy
                    ? null
                    : () => controller.add(context),
                child: Text(l.prototypeAdd),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mobileForm(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    Widget field(String label, Widget input) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 6,
      children: [
        Text(
          label,
          style: AppTypography.geodataField.copyWith(
            color: palette.mutedStrong,
          ),
        ),
        input,
      ],
    );
    final buttonStyle = FilledButton.styleFrom(
      minimumSize: const Size(84, 38),
      padding: const EdgeInsets.symmetric(horizontal: 13),
      textStyle: AppTypography.control,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.standard,
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: palette.muted,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          field(
            l.prototypeDataType,
            SizedBox(
              width: double.infinity,
              child: SettingSelect<GeoDataType>(
                value: controller.type,
                entries: const {
                  GeoDataType.ip: 'GeoIP',
                  GeoDataType.domain: 'GeoSite',
                },
                textStyle: AppTypography.geodataField,
                onChanged: controller.busy ? null : controller.changeType,
              ),
            ),
          ),
          field(
            l.prototypeSavedFileName,
            ShadInput(
              controller: controller.name,
              enabled: !controller.busy,
              autofocus: true,
              autocorrect: false,
              textDirection: TextDirection.ltr,
              constraints: const BoxConstraints(minHeight: 38),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              style: AppTypography.geodataField,
              placeholderStyle: AppTypography.geodataField.copyWith(
                color: palette.mutedForeground,
              ),
              placeholder: Text(
                controller.type == GeoDataType.ip ? 'geoip.dat' : 'geosite.dat',
              ),
            ),
          ),
          field(
            l.prototypeHttpsDownloadAddress,
            ShadInput(
              controller: controller.url,
              enabled: !controller.busy,
              keyboardType: TextInputType.url,
              autocorrect: false,
              textDirection: TextDirection.ltr,
              constraints: const BoxConstraints(minHeight: 38),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              style: AppTypography.geodataField,
              placeholderStyle: AppTypography.geodataField.copyWith(
                color: palette.mutedForeground,
              ),
              placeholder: const Text('https://example.com/geoip.dat'),
            ),
          ),
          if (controller.formError != null)
            _error(context, controller.formError!),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            spacing: 7,
            children: [
              Flexible(
                child: OutlinedButton(
                  style: buttonStyle,
                  onPressed: controller.busy ? null : controller.toggleAdd,
                  child: Text(l.prototypeCancel),
                ),
              ),
              Flexible(
                child: FilledButton(
                  style: buttonStyle,
                  onPressed: controller.busy
                      ? null
                      : () => controller.add(context),
                  child: Text(l.prototypeAdd),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
