import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/share/controller.dart';
import 'package:onexray/pages/home/share/params.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SharePage extends StatelessWidget {
  final SharePageParams params;

  const SharePage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ShareController(params),
      child: BlocBuilder<ShareController, ShareState>(
        builder: (context, state) => Scaffold(
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)!.sharePageTitle),
          ),
          body: SafeArea(child: _body(context, state)),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, ShareState state) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: SingleChildScrollView(
        child: ResponsiveContent(
          child: Column(
            children: [
              if (state.showLinkSection) _linkSection(context, state),
              if (state.showTextSection) _textSection(context, state),
              if (state.showJsonFileSection) _jsonFileSection(context, state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linkSection(BuildContext context, ShareState state) {
    final controller = context.read<ShareController>();
    return Column(
      children: [
        if (state.linkQrcodeSuccess)
          _linkQrcodeSection(context, controller, state.linkSection),
        _linkUrlSection(context, controller, state.linkSection),
      ],
    );
  }

  Widget _linkQrcodeSection(
    BuildContext context,
    ShareController controller,
    String sectionTitle,
  ) {
    return SettingSection(
      title: "$sectionTitle / ${AppLocalizations.of(context)!.sharePageQRCode}",
      children: [
        if (!AppPlatform.isLinux)
          NavigationSettingRow(
            title: AppLocalizations.of(context)!.sharePageShareQRCode,
            onTap: () => controller.shareLinkQrcode(context),
          ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.sharePageSaveQRCode,
          onTap: () => controller.saveLinkQrcode(context),
        ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.sharePageShowQRCode,
          onTap: () => controller.showLinkQrcode(context),
        ),
      ],
    );
  }

  Widget _linkUrlSection(
    BuildContext context,
    ShareController controller,
    String sectionTitle,
  ) {
    return SettingSection(
      title: "$sectionTitle / ${AppLocalizations.of(context)!.sharePageLink}",
      children: [
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.sharePageShareLink,
          onTap: () => controller.shareLinkUrl(context),
        ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.sharePageCopyLink,
          onTap: () => controller.copyLinkUrl(context),
        ),
      ],
    );
  }

  Widget _textSection(BuildContext context, ShareState state) {
    final controller = context.read<ShareController>();
    return SettingSection(
      title:
          "${state.textSection} / ${AppLocalizations.of(context)!.sharePageText}",
      children: [
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.sharePageShareText,
          onTap: () => controller.shareText(context),
        ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.sharePageCopyText,
          onTap: () => controller.copyText(context),
        ),
      ],
    );
  }

  Widget _jsonFileSection(BuildContext context, ShareState state) {
    final controller = context.read<ShareController>();
    return SettingSection(
      title:
          "${state.jsonFileSection} / ${AppLocalizations.of(context)!.sharePageJsonFile}",
      children: [
        if (!AppPlatform.isLinux)
          NavigationSettingRow(
            title: AppLocalizations.of(context)!.sharePageShareJsonFile,
            onTap: () => controller.shareJsonFile(context),
          ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.sharePageSaveJsonFile,
          onTap: () => controller.saveJsonFile(context),
        ),
      ],
    );
  }
}
