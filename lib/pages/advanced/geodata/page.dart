import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/core/model/geo_data_type.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/geodata/controller.dart';
import 'package:onexray/pages/advanced/geodata/view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';

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
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(l.prototypeRoutingDataHint),
                        const SizedBox(height: 12),
                        Align(
                          alignment: AlignmentDirectional.centerEnd,
                          child: FilledButton.icon(
                            onPressed: controller.busy
                                ? null
                                : () => controller.updateAll(context),
                            icon: const Icon(LucideIcons.refreshCw, size: 18),
                            label: Text(l.prototypeUpdateAll),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l.prototypeHttpsOnly,
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (controller.busy)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: LinearProgressIndicator(),
                          ),
                        const SizedBox(height: 28),
                        _heading(
                          context,
                          l.prototypeDefaultRoutingData,
                          OutlinedButton.icon(
                            onPressed: controller.busy
                                ? null
                                : () => controller.update(context, null),
                            icon: const Icon(LucideIcons.refreshCw, size: 18),
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
                        const SizedBox(height: 28),
                        _heading(
                          context,
                          l.prototypeCustomRoutingData,
                          OutlinedButton.icon(
                            onPressed: controller.busy
                                ? null
                                : controller.toggleAdd,
                            icon: const Icon(LucideIcons.plus, size: 18),
                            label: Text(l.prototypeAddDataSource),
                          ),
                        ),
                        if (controller.adding) _form(context),
                        if (controller.custom.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(l.prototypeNoCustomRoutingData),
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

  Widget _heading(BuildContext context, String title, Widget action) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Align(
            alignment: AlignmentDirectional.centerEnd,
            child: action,
          ),
        ),
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
}
