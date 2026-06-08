import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/share/controller.dart';
import 'package:onexray/pages/home/share/params.dart';
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
        child: Column(
          children: [
            if (state.showLinkSection) _linkSection(context, state),
            _appSection(context, state),
          ],
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

  Widget _appSection(BuildContext context, ShareState state) {
    final controller = context.read<ShareController>();
    return SettingSection(
      title:
          "${AppLocalizations.of(context)!.sharePageAppLink} / ${AppLocalizations.of(context)!.sharePageLink}",
      children: [
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.sharePageShareLink,
          onTap: () => controller.shareAppUrl(context),
        ),
        NavigationSettingRow(
          title: AppLocalizations.of(context)!.sharePageCopyLink,
          onTap: () => controller.copyAppUrl(context),
        ),
      ],
    );
  }
}
