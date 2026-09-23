import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:onexray/core/constants/donation.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/settings/donation/controller.dart';
import 'package:onexray/pages/shared/widgets/button_progress.dart';
import 'package:onexray/pages/shared/widgets/page_app_bar.dart';
import 'package:onexray/pages/shared/widgets/setting_row.dart';
import 'package:onexray/pages/shared/widgets/settings_page.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class DonationPage extends StatelessWidget {
  const DonationPage({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => DonationController(),
    child: BlocBuilder<DonationController, bool>(
      builder: (context, copying) {
        final l10n = AppLocalizations.of(context)!;
        final mobile =
            MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
        return Scaffold(
          appBar: PageAppBar(title: Text(l10n.donationTitle)),
          body: SafeArea(
            child: SettingsPageScroll(
              desktopMaxWidth: AppLayout.routingMaxWidth,
              padding: EdgeInsets.all(
                mobile ? AppSpacing.mobilePage : AppSpacing.page,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.donationDescription,
                    style: AppTypography.supporting,
                  ),
                  const SizedBox(height: 24),
                  SettingSection(
                    title: l10n.donationTitle,
                    icon: LucideIcons.heart,
                    padding: EdgeInsets.zero,
                    dividerIndent: 0,
                    children: [
                      SettingRow(
                        title: l10n.donationNetwork,
                        value: DonationInfo.network,
                        valueTextDirection: TextDirection.ltr,
                      ),
                      SettingRow(
                        title: l10n.donationAssets,
                        value: DonationInfo.assets,
                        valueTextDirection: TextDirection.ltr,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SettingSection(
                    title: l10n.donationAddress,
                    padding: EdgeInsets.zero,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: SelectableText(
                                DonationInfo.address,
                                textDirection: TextDirection.ltr,
                                style: AppTypography.code,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.controlHorizontal),
                            IconButton(
                              iconSize: 18,
                              tooltip: l10n.donationCopyAddress,
                              onPressed: copying
                                  ? null
                                  : () => context
                                        .read<DonationController>()
                                        .copyAddress(context),
                              icon: copying
                                  ? const ButtonProgressIndicator()
                                  : const Icon(LucideIcons.copy),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.donationNetworkWarning,
                    style: AppTypography.supporting.copyWith(
                      color: ColorManager.secondaryText(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
