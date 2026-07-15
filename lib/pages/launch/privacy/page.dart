import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/launch/privacy/controller.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PrivacyController(),
      child: BlocBuilder<PrivacyController, PrivacyPageState>(
        builder: (context, state) {
          final controller = context.read<PrivacyController>();
          final l10n = AppLocalizations.of(context)!;
          return Scaffold(
            appBar: AppBar(title: Text(l10n.privacyPageTitle)),
            body: SafeArea(
              child: PrivacyView(
                markdown: state.md,
                onOpenLink: controller.openUrl,
                onAccept: () => controller.accept(context),
              ),
            ),
          );
        },
      ),
    );
  }
}

class PrivacyView extends StatelessWidget {
  final String markdown;
  final ValueChanged<String?> onOpenLink;
  final VoidCallback onAccept;

  const PrivacyView({
    super.key,
    required this.markdown,
    required this.onOpenLink,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 24),
            child: ResponsiveContent(
              desktopMaxWidth: 860,
              child: ShadCard(
                width: double.infinity,
                padding: const EdgeInsetsDirectional.fromSTEB(22, 20, 22, 24),
                radius: const BorderRadius.all(Radius.circular(8)),
                child: MarkdownBody(
                  data: markdown,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
                  onTapLink: (_, href, _) => onOpenLink(href),
                ),
              ),
            ),
          ),
        ),
        SettingsActionBar(
          actions: [
            ShadButton(
              leading: const Icon(LucideIcons.shieldCheck, size: 16),
              onPressed: onAccept,
              child: Text(l10n.privacyPageAccept),
            ),
          ],
        ),
      ],
    );
  }
}
