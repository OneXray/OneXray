import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/launch/setup/widgets.dart';
import 'package:onexray/pages/widget/button_progress.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/service/doc/helper.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class _PrivacyController extends PageCubit<({bool busy, bool failed})> {
  _PrivacyController() : super((busy: false, failed: false));

  Future<void> openPolicy() async {
    if (state.busy) return;
    emit((busy: true, failed: false));
    try {
      final opened = await launchUrl(DocURLHelper.privacyUri());
      emit((busy: false, failed: !opened));
    } catch (_) {
      emit((busy: false, failed: true));
    }
  }

  void back(BuildContext context) => context.pop();
}

class SetupPrivacyPage extends StatelessWidget {
  const SetupPrivacyPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => _PrivacyController(),
    child: BlocBuilder<_PrivacyController, ({bool busy, bool failed})>(
      builder: (context, state) {
        final controller = context.read<_PrivacyController>();
        return SetupPrivacyView(
          busy: state.busy,
          failureText: state.failed
              ? AppLocalizations.of(context)!.prototypeTemporarilyUnavailable
              : null,
          onBack: () => controller.back(context),
          onOpenPolicy: controller.openPolicy,
        );
      },
    ),
  );
}

class SetupPrivacyView extends StatelessWidget {
  const SetupPrivacyView({
    super.key,
    this.busy = false,
    this.failureText,
    required this.onBack,
    required this.onOpenPolicy,
  });

  final bool busy;
  final String? failureText;
  final VoidCallback onBack;
  final VoidCallback onOpenPolicy;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final palette = ColorManager.palette(context);
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    final detailStyle =
        (mobile ? AppTypography.setupPoint : AppTypography.setupDesktopPoint)
            .copyWith(color: palette.mutedStrong);
    return Scaffold(
      appBar: mobile
          ? null
          : AppBar(
              leading: IconButton(
                tooltip: l.prototypeBack,
                onPressed: onBack,
                icon: const Icon(LucideIcons.arrowLeftDir),
              ),
              title: Text(l.prototypePrivacyPolicy),
            ),
      body: SafeArea(
        bottom: false,
        child: SetupBody(
          top: mobile ? 56 : 24,
          children: [
            if (mobile) ...[
              Text(l.prototypePrivacyPolicy, style: AppTypography.setupTitle),
              const SizedBox(height: 12),
            ],
            Text(
              l.prototypeNoDataUpload,
              style: AppTypography.setupSubtitle.copyWith(
                color: palette.mutedStrong,
              ),
            ),
            const SizedBox(height: 36),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: mobile ? 760 : 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.prototypeConfiguredSourcesNotice,
                      style: detailStyle,
                    ),
                    const SizedBox(height: 24),
                    Text(l.prototypeRegionPrivacyNotice, style: detailStyle),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: busy ? null : onOpenPolicy,
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 38),
                        alignment: AlignmentDirectional.topStart,
                        foregroundColor: palette.mutedStrong,
                        textStyle: detailStyle.copyWith(
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: ButtonProgress(
                              busy: busy,
                              child: Text(l.prototypeReadFullPrivacyPolicy),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            LucideIcons.chevronRightDir,
                            size: 16,
                            color: palette.primary,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (failureText != null) SetupError(text: failureText!),
          ],
        ),
      ),
      bottomNavigationBar: SetupFooter(
        children: [
          SetupActionButton(label: l.prototypeBack, onPressed: onBack),
        ],
      ),
    );
  }
}
