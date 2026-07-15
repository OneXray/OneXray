import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/launch/first_run/controller.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/tun_settings/state.dart';
import 'package:onexray/service/xray/profile/enum.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class FirstRunPage extends StatelessWidget {
  const FirstRunPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FirstRunController(),
      child: BlocBuilder<FirstRunController, FirstRunPageState>(
        builder: (context, state) {
          final controller = context.read<FirstRunController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.firstRunPageTitle),
            ),
            body: SafeArea(
              child: FirstRunView(
                state: state,
                showInterfaces: AppPlatform.isWindows || AppPlatform.isLinux,
                onCountryChanged: controller.updateCountry,
                onInterfaceChanged: controller.updateInterface,
                onIPv6Changed: controller.updateEnableIPv6,
                onContinue: () => controller.nextStep(context),
              ),
            ),
          );
        },
      ),
    );
  }
}

class FirstRunView extends StatelessWidget {
  final FirstRunPageState state;
  final bool showInterfaces;
  final ValueChanged<SimpleCountry?> onCountryChanged;
  final ValueChanged<String?> onInterfaceChanged;
  final ValueChanged<bool> onIPv6Changed;
  final VoidCallback onContinue;

  const FirstRunView({
    super.key,
    required this.state,
    required this.showInterfaces,
    required this.onCountryChanged,
    required this.onInterfaceChanged,
    required this.onIPv6Changed,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Expanded(
          child: SettingsPageScroll(
            desktopMaxWidth: 760,
            child: Column(
              children: [
                _intro(context),
                _countrySection(context),
                _networkSection(context),
                if (showInterfaces) _interfaceSection(context),
              ],
            ),
          ),
        ),
        SettingsActionBar(
          actions: [
            ShadButton(onPressed: onContinue, child: Text(l10n.buttonNextStep)),
          ],
        ),
      ],
    );
  }

  Widget _intro(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 22, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ShadBadge.secondary(child: Text(l10n.firstRunPageStep)),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.firstRunPageIntroTitle,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            l10n.firstRunPageIntroDescription,
            style: AppTypography.supporting.copyWith(
              color: ColorManager.secondaryText(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _countrySection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingSection(
      title: l10n.firstRunPageCountryTitle,
      description: l10n.firstRunPageCountrySection,
      separated: false,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 600 ? 4 : 2;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: SimpleCountry.values.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: columns == 4 ? 1.75 : 1.65,
                ),
                itemBuilder: (context, index) {
                  final country = SimpleCountry.values[index];
                  return _CountryChoice(
                    country: country,
                    selected: state.country == country,
                    onTap: () => onCountryChanged(country),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _networkSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingSection(
      title: l10n.firstRunPageNetworkTitle,
      children: [
        SwitchSettingRow(
          title: l10n.tunSettingsPageEnableIPv6,
          subtitle: l10n.tunSettingsPageEnableIPv6Tip,
          leading: const Icon(LucideIcons.network),
          value: state.enableIPv6,
          onChanged: onIPv6Changed,
        ),
      ],
    );
  }

  Widget _interfaceSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SettingSection(
      title: l10n.firstRunPageInterfaceTitle,
      description: l10n.firstRunPageInterfaceSection,
      children: [
        SettingsChoiceRow(
          title: l10n.networkInterfacePageAuto,
          description: l10n.firstRunPageInterfaceAutoDescription,
          leading: const Icon(LucideIcons.network),
          selected:
              state.interface == TunSettingsState.autoOutboundsInterfaceAuto,
          onTap: () =>
              onInterfaceChanged(TunSettingsState.autoOutboundsInterfaceAuto),
        ),
        ...state.interfaces.map((networkInterface) {
          final addresses = networkInterface.addresses
              .map((address) => address.address)
              .join(" · ");
          return SettingsChoiceRow(
            title: networkInterface.name,
            description: addresses,
            leading: const Icon(LucideIcons.network),
            selected: state.interface == networkInterface.name,
            onTap: () => onInterfaceChanged(networkInterface.name),
          );
        }),
      ],
    );
  }
}

class _CountryChoice extends StatelessWidget {
  final SimpleCountry country;
  final bool selected;
  final VoidCallback onTap;

  const _CountryChoice({
    required this.country,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? ColorManager.selected(context)
                : ColorManager.surface(context),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? primary : ColorManager.border(context),
            ),
          ),
          child: Row(
            children: [
              const Icon(LucideIcons.globe2, size: 18),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  country.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              SettingsChoiceIndicator(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}
