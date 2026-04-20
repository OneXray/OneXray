import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/share/controller.dart';
import 'package:onexray/pages/home/share/params.dart';
import 'package:onexray/pages/widget/section.dart';
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
    return SectionView(
      title: state.linkSection,
      child: Column(
        children: [
          if (state.linkQrcodeSuccess)
            _linkQrcodeSection(context, controller),
          _linkUrlSection(context, controller),
        ],
      ),
    );
  }

  Widget _linkQrcodeSection(BuildContext context, ShareController controller) {
    return SectionView(
      title: AppLocalizations.of(context)!.sharePageQRCode,
      level: SectionLevel.second,
      child: Column(
        children: [
          if (!AppPlatform.isLinux)
            ListTile(
              onTap: () => controller.shareLinkQrcode(context),
              title: Text(AppLocalizations.of(context)!.sharePageShareQRCode),
            ),
          ListTile(
            onTap: () => controller.saveLinkQrcode(context),
            title: Text(AppLocalizations.of(context)!.sharePageSaveQRCode),
          ),
          ListTile(
            onTap: () => controller.showLinkQrcode(context),
            title: Text(AppLocalizations.of(context)!.sharePageShowQRCode),
          ),
        ],
      ),
    );
  }

  Widget _linkUrlSection(BuildContext context, ShareController controller) {
    return SectionView(
      title: AppLocalizations.of(context)!.sharePageLink,
      level: SectionLevel.second,
      child: Column(
        children: [
          ListTile(
            onTap: () => controller.shareLinkUrl(context),
            title: Text(AppLocalizations.of(context)!.sharePageShareLink),
          ),
          ListTile(
            onTap: () => controller.copyLinkUrl(context),
            title: Text(AppLocalizations.of(context)!.sharePageCopyLink),
          ),
        ],
      ),
    );
  }

  Widget _appSection(BuildContext context, ShareState state) {
    final controller = context.read<ShareController>();
    return SectionView(
      title: AppLocalizations.of(context)!.sharePageAppLink,
      child: _appUrlSection(context, controller),
    );
  }

  Widget _appUrlSection(BuildContext context, ShareController controller) {
    return SectionView(
      title: AppLocalizations.of(context)!.sharePageLink,
      level: SectionLevel.second,
      child: Column(
        children: [
          ListTile(
            onTap: () => controller.shareAppUrl(context),
            title: Text(AppLocalizations.of(context)!.sharePageShareLink),
          ),
          ListTile(
            onTap: () => controller.copyAppUrl(context),
            title: Text(AppLocalizations.of(context)!.sharePageCopyLink),
          ),
        ],
      ),
    );
  }
}
