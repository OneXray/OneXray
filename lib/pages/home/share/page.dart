import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/home/share/controller.dart';
import 'package:onexray/pages/home/share/params.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SharePage extends StatelessWidget {
  const SharePage({super.key, required this.params});

  final SharePageParams params;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ShareController(params),
      child: BlocBuilder<ShareController, SharePageState>(
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)!.sharePageTitle),
          ),
          body: SafeArea(child: _body(context, state)),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, SharePageState state) {
    final description = state.showLinkSection
        ? state.linkSection
        : state.showTextSection
        ? state.textSection
        : "";
    if (!state.showLinkSection &&
        !state.showTextSection &&
        !state.showJsonFileSection) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      child: ResponsiveContent(
        desktopMaxWidth: 760,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 18, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (description.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsetsDirectional.symmetric(horizontal: 2),
                  child: Text(
                    description,
                    style: AppTypography.supporting.copyWith(
                      color: ColorManager.secondaryText(context),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              if (state.showLinkSection) ..._linkSections(context, state),
              if (state.showTextSection) ..._textSections(context),
              if (state.showJsonFileSection) ..._jsonFileSections(context),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _linkSections(BuildContext context, SharePageState state) {
    final localizations = AppLocalizations.of(context)!;
    final controller = context.read<ShareController>();
    return [
      if (state.linkQrcodeSuccess) ...[
        _ShareActionSection(
          title: localizations.sharePageQRCode,
          actions: [
            if (!AppPlatform.isLinux)
              _ShareAction(
                title: localizations.sharePageShareQRCode,
                icon: LucideIcons.share2,
                onTap: () => controller.shareLinkQrcode(context),
              ),
            _ShareAction(
              title: localizations.sharePageSaveQRCode,
              icon: LucideIcons.imageDown,
              onTap: () => controller.saveLinkQrcode(context),
            ),
            _ShareAction(
              title: localizations.sharePageShowQRCode,
              icon: LucideIcons.qrCode,
              onTap: () => controller.showLinkQrcode(context),
            ),
          ],
        ),
        const SizedBox(height: 18),
      ],
      _ShareActionSection(
        title: localizations.sharePageLink,
        actions: [
          _ShareAction(
            title: localizations.sharePageShareLink,
            icon: LucideIcons.share2,
            onTap: () => controller.shareLinkUrl(context),
          ),
          _ShareAction(
            title: localizations.sharePageCopyLink,
            icon: LucideIcons.copy,
            onTap: () => controller.copyLinkUrl(context),
          ),
        ],
      ),
      const SizedBox(height: 18),
    ];
  }

  List<Widget> _textSections(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final controller = context.read<ShareController>();
    return [
      _ShareActionSection(
        title: localizations.sharePageText,
        actions: [
          _ShareAction(
            title: localizations.sharePageShareText,
            icon: LucideIcons.share2,
            onTap: () => controller.shareText(context),
          ),
          _ShareAction(
            title: localizations.sharePageCopyText,
            icon: LucideIcons.copy,
            onTap: () => controller.copyText(context),
          ),
        ],
      ),
      const SizedBox(height: 18),
    ];
  }

  List<Widget> _jsonFileSections(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final controller = context.read<ShareController>();
    return [
      _ShareActionSection(
        title: localizations.sharePageJsonFile,
        actions: [
          if (!AppPlatform.isLinux)
            _ShareAction(
              title: localizations.sharePageShareJsonFile,
              icon: LucideIcons.share2,
              onTap: () => controller.shareJsonFile(context),
            ),
          _ShareAction(
            title: localizations.sharePageSaveJsonFile,
            icon: LucideIcons.fileJson,
            onTap: () => controller.saveJsonFile(context),
          ),
        ],
      ),
    ];
  }
}

class _ShareAction {
  const _ShareAction({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;
}

class _ShareActionSection extends StatelessWidget {
  const _ShareActionSection({required this.title, required this.actions});

  final String title;
  final List<_ShareAction> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 2, bottom: 7),
          child: Text(
            title,
            style: AppTypography.supporting.copyWith(
              fontWeight: FontWeight.w600,
              color: ColorManager.secondaryText(context),
            ),
          ),
        ),
        ShadCard(
          width: double.infinity,
          padding: EdgeInsets.zero,
          radius: const BorderRadius.all(Radius.circular(8)),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var index = 0; index < actions.length; index++) ...[
                if (index > 0)
                  Divider(height: 1, color: ColorManager.border(context)),
                _ShareActionRow(action: actions[index]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ShareActionRow extends StatelessWidget {
  const _ShareActionRow({required this.action});

  final _ShareAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    action.icon,
                    size: 15,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(action.title, style: AppTypography.rowTitle),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
