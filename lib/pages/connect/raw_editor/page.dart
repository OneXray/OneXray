import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/connect/raw_editor/controller.dart';
import 'package:onexray/pages/routing/widgets.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/widget/button_progress.dart';
import 'package:onexray/pages/widget/configuration_transfer.dart';
import 'package:onexray/pages/widget/json_editor.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
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
    unawaited(controller.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => BlocProvider.value(
    value: controller,
    child: BlocBuilder<RawEditorController, RawEditorPageState>(
      builder: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        final mobile =
            MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
        final palette = ColorManager.palette(context);
        final gap = mobile ? 16.0 : 20.0;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              widget.rawId == null
                  ? l10n.prototypeAddRawJson
                  : l10n.prototypeEditRawJson,
            ),
            leading: BackButton(onPressed: () => controller.closePage(context)),
          ),
          body: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                mobile ? 14 : AppSpacing.page,
                mobile ? 12 : AppSpacing.desktopPageTop,
                mobile ? 14 : AppSpacing.page,
                mobile ? 12 : AppSpacing.desktopPageBottom,
              ),
              child: ResponsiveContent(
                desktopMaxWidth: 900,
                child: RoutingCard(
                  padding: EdgeInsets.symmetric(
                    horizontal: mobile ? 12 : 20,
                    vertical: mobile ? 14 : 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ConfigurationTransferTools(
                        controller: controller.transfers,
                        disabled: state.busy || !state.loaded,
                      ),
                      if (state.sharingDataCount case final count?
                          when count > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _RawNote(
                            l10n.prototypeSharingDataSourceLinks(count),
                          ),
                        ),
                      SizedBox(height: gap),
                      Text(
                        l10n.prototypeConfigurationName,
                        style: AppTypography.rawField.copyWith(
                          color: palette.mutedStrong,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 42,
                        child: TextField(
                          controller: controller.name,
                          maxLength: 32,
                          enabled: state.loaded,
                          style: AppTypography.rawField,
                          decoration: InputDecoration(
                            hintText: l10n.prototypeConfigurationName,
                            hintStyle: AppTypography.rawField.copyWith(
                              color: palette.mutedForeground,
                            ),
                            counterText: '',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: gap),
                      Text(
                        l10n.prototypeCompleteXrayConfiguration,
                        style: AppTypography.rawField.copyWith(
                          color: palette.mutedStrong,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: mobile ? 392 : 412,
                        child: AbsorbPointer(
                          absorbing: !state.loaded,
                          child: AppJsonEditor(controller: controller.text),
                        ),
                      ),
                      SizedBox(height: gap),
                      _RawNote(l10n.prototypeRawManagedSettingsNotice),
                      SizedBox(height: gap),
                      _RawNote(l10n.prototypeRawAdditionalSettingsNotice),
                      if (!state.loaded && state.busy)
                        const LinearProgressIndicator(),
                      if (state.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Semantics(
                            liveRegion: true,
                            child: Text(
                              state.error!,
                              style: AppTypography.rawNote.copyWith(
                                color: palette.destructive,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          bottomNavigationBar: PageActionBar(
            children: [
              if (!mobile)
                ShadButton.outline(
                  onPressed: () => controller.closePage(context),
                  child: Text(l10n.prototypeCancel),
                ),
              ShadButton(
                enabled: controller.canSave,
                onPressed: controller.canSave
                    ? () => controller.save(context)
                    : null,
                child: ButtonProgress(
                  busy: state.loaded && state.busy,
                  child: Text(l10n.prototypeSave),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _RawNote extends StatelessWidget {
  final String text;
  const _RawNote(this.text);

  @override
  Widget build(BuildContext context) {
    final palette = ColorManager.palette(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(LucideIcons.info, size: 16, color: palette.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AppTypography.rawNote.copyWith(
              color: palette.mutedForeground,
            ),
          ),
        ),
      ],
    );
  }
}
