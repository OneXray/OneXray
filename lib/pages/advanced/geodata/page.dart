import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:onexray/core/model/geo_data_type.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/advanced/geodata/controller.dart';
import 'package:onexray/pages/advanced/geodata/view.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/button_progress.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadInput;

class GeoDataPage extends StatefulWidget {
  const GeoDataPage({super.key, required this.openFile});
  final void Function(BuildContext, int) openFile;
  @override
  State<GeoDataPage> createState() => _GeoDataPageState();
}

class _GeoDataPageState extends State<GeoDataPage> {
  final scroll = ScrollController();

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => GeoDataController()..initialize(),
    child: BlocBuilder<GeoDataController, GeoDataPageState>(
      builder: (context, state) {
        final controller = context.read<GeoDataController>();
        final l = AppLocalizations.of(context)!;
        final mobile =
            MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
        final palette = ColorManager.palette(context);
        return Scaffold(
          appBar: AppBar(title: Text(l.prototypeRoutingData)),
          body: SafeArea(
            child: ResponsiveContent(
              desktopMaxWidth: AppLayout.advancedMaxWidth,
              child: state.loading
                  ? const Center(child: CircularProgressIndicator())
                  : state.failed
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
                            : EdgeInsets.fromLTRB(
                                AppSpacing.advancedDesktopGutter(
                                  MediaQuery.sizeOf(context).width,
                                ),
                                54,
                                AppSpacing.advancedDesktopGutter(
                                  MediaQuery.sizeOf(context).width,
                                ),
                                28,
                              ),
                        children: [
                          _intro(context, state, controller),
                          SizedBox(height: mobile ? 7 : 16),
                          _heading(
                            context,
                            l.prototypeDefaultRoutingData,
                            OutlinedButton.icon(
                              style: _headingButtonStyle(context),
                              onPressed: state.fileBusy(-1)
                                  ? null
                                  : () => controller.update(context, null),
                              icon: state.updating.contains(-1)
                                  ? const ButtonProgressIndicator()
                                  : const Icon(LucideIcons.refreshCw, size: 16),
                              label: Text(l.prototypeUpdate),
                            ),
                          ),
                          GeoDataRows(
                            files: state.defaults,
                            custom: false,
                            busy: state.updatingAll,
                            onOpen: (file) =>
                                widget.openFile(context, file.row.id),
                            onUpdate: (file) =>
                                controller.update(context, file),
                            onDelete: (file) =>
                                controller.delete(context, file),
                          ),
                          if (state.errors[-1] != null)
                            _error(context, state.errors[-1]!),
                          SizedBox(height: mobile ? 18 : 24),
                          _heading(
                            context,
                            l.prototypeCustomRoutingData,
                            OutlinedButton.icon(
                              style: _headingButtonStyle(context),
                              onPressed: state.formBusy
                                  ? null
                                  : controller.toggleAdd,
                              icon: const Icon(LucideIcons.plus, size: 16),
                              label: Text(l.prototypeAddDataSource),
                            ),
                          ),
                          if (state.adding) _form(context, state, controller),
                          if (state.custom.isEmpty)
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
                                style:
                                    (mobile
                                            ? AppTypography.settingsDetailNote
                                            : AppTypography.geodataTableBody)
                                        .copyWith(
                                          color: palette.mutedForeground,
                                        ),
                              ),
                            )
                          else
                            GeoDataRows(
                              files: state.custom,
                              custom: true,
                              busy: state.updatingAll,
                              updating: state.updating,
                              deleting: state.deleting,
                              onOpen: (file) =>
                                  widget.openFile(context, file.row.id),
                              onUpdate: (file) =>
                                  controller.update(context, file),
                              onDelete: (file) =>
                                  controller.delete(context, file),
                            ),
                          for (final file in state.custom)
                            if (state.errors[file.row.id] != null)
                              _error(
                                context,
                                '${file.fileName}: ${state.errors[file.row.id]}',
                              ),
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
    ),
  );

  Widget _intro(
    BuildContext context,
    GeoDataPageState state,
    GeoDataController controller,
  ) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    final description = Text(
      l.prototypeRoutingDataHint,
      style:
          (mobile
                  ? AppTypography.geodataIntro
                  : AppTypography.geodataDesktopIntro)
              .copyWith(color: palette.mutedForeground),
    );
    final actions = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: mobile
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.end,
      children: [
        FilledButton.icon(
          style: mobile
              ? FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: AppTypography.geodataPrimaryAction,
                )
              : FilledButton.styleFrom(minimumSize: const Size(132, 42)),
          onPressed: !state.canUpdateAll
              ? null
              : () => controller.updateAll(context),
          icon: state.updatingAll
              ? const ButtonProgressIndicator(size: 15)
              : const Icon(LucideIcons.refreshCw, size: 15),
          label: Text(l.prototypeUpdateAll),
        ),
        const SizedBox(height: 5),
        Text(
          l.prototypeHttpsOnly,
          textAlign: mobile ? TextAlign.center : TextAlign.end,
          style: AppTypography.geodataValue.copyWith(
            color: palette.mutedForeground,
          ),
        ),
      ],
    );
    return mobile
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [description, const SizedBox(height: 10), actions],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: description),
              const SizedBox(width: 20),
              actions,
            ],
          );
  }

  ButtonStyle _headingButtonStyle(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    return OutlinedButton.styleFrom(
      minimumSize: Size(0, mobile ? 34 : 36),
      padding: EdgeInsets.symmetric(horizontal: mobile ? 9 : 12),
      textStyle: mobile ? AppTypography.geodataAction : null,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _heading(BuildContext context, String title, Widget action) {
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: mobile ? 42 : 44),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: mobile
                  ? AppTypography.geodataTitle
                  : AppTypography.geodataDesktopTitle,
            ),
          ),
          SizedBox(width: mobile ? 12 : 16),
          action,
        ],
      ),
    );
  }

  Widget _error(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: Theme.of(context).colorScheme.error),
    ),
  );

  Widget _form(
    BuildContext context,
    GeoDataPageState state,
    GeoDataController controller,
  ) {
    final viewport = MediaQuery.sizeOf(context).width;
    final mobile = viewport <= AppLayout.mobileBreakpoint;
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
      minimumSize: Size(mobile ? 84 : 0, 38),
      padding: const EdgeInsets.symmetric(horizontal: 13),
      textStyle: AppTypography.control,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
    final typeField = field(
      l.prototypeDataType,
      SizedBox(
        width: double.infinity,
        child: SettingSelect<GeoDataType>(
          value: state.type,
          entries: const {
            GeoDataType.ip: 'GeoIP',
            GeoDataType.domain: 'GeoSite',
          },
          textStyle: AppTypography.geodataField,
          onChanged: state.formBusy ? null : controller.changeType,
        ),
      ),
    );
    final nameField = field(
      l.prototypeSavedFileName,
      ShadInput(
        controller: controller.name,
        enabled: !state.formBusy,
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
          state.type == GeoDataType.ip ? 'geoip.dat' : 'geosite.dat',
        ),
      ),
    );
    final urlField = field(
      l.prototypeHttpsDownloadAddress,
      ShadInput(
        controller: controller.url,
        enabled: !state.formBusy,
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
    );
    final actions = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      spacing: 7,
      children: [
        Flexible(
          child: OutlinedButton(
            style: buttonStyle,
            onPressed: state.formBusy ? null : controller.toggleAdd,
            child: Text(l.prototypeCancel),
          ),
        ),
        Flexible(
          child: FilledButton(
            style: buttonStyle,
            onPressed: state.formBusy ? null : () => controller.add(context),
            child: ButtonProgress(
              busy: state.formBusy,
              child: Text(l.prototypeAdd),
            ),
          ),
        ),
      ],
    );
    return Container(
      margin: EdgeInsets.only(bottom: mobile ? 12 : 16),
      padding: mobile
          ? const EdgeInsets.all(11)
          : const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: palette.muted,
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: mobile ? 10 : 12,
        children: [
          if (mobile) ...[
            typeField,
            nameField,
            urlField,
            Align(alignment: AlignmentDirectional.centerEnd, child: actions),
          ] else if (viewport <= AppLayout.compactDesktopBreakpoint) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(width: 120, child: typeField),
                const SizedBox(width: 12),
                Expanded(child: nameField),
              ],
            ),
            urlField,
            Align(alignment: AlignmentDirectional.centerEnd, child: actions),
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(width: 120, child: typeField),
                const SizedBox(width: 12),
                SizedBox(width: 170, child: nameField),
                const SizedBox(width: 12),
                Expanded(child: urlField),
                const SizedBox(width: 12),
                actions,
              ],
            ),
          if (state.formError != null) _error(context, state.formError!),
        ],
      ),
    );
  }
}
