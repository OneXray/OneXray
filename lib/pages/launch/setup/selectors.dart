import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';
import 'package:onexray/pages/widget/settings_page.dart';
import 'package:onexray/service/launch/setup.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SetupInterfaceParams {
  final List<SetupInterface> interfaces;
  final String selected;
  const SetupInterfaceParams(this.interfaces, this.selected);
}

class SetupRegionParams {
  final List<String> codes;
  final String selected;
  const SetupRegionParams(this.codes, this.selected);
}

String setupRegionLabel(AppLocalizations l10n, String code) => switch (code) {
  'CN' => l10n.prototypeMainlandChina,
  'RU' => l10n.prototypeRussia,
  'IR' => l10n.prototypeIran,
  'HK' => l10n.prototypeHongKong,
  'JP' => l10n.prototypeJapan,
  'SG' => l10n.prototypeSingapore,
  'KR' => l10n.prototypeSouthKorea,
  'US' => l10n.prototypeUnitedStates,
  'CA' => l10n.prototypeCanada,
  'DE' => l10n.prototypeGermany,
  'GB' => l10n.prototypeUnitedKingdom,
  'FR' => l10n.prototypeFrance,
  'IN' => l10n.prototypeIndia,
  'AU' => l10n.prototypeAustralia,
  'BR' => l10n.prototypeBrazil,
  'TR' => l10n.prototypeTurkey,
  _ => code, // The remaining official codes have no approved translated names.
};

class SetupInterfacePage extends StatelessWidget {
  final SetupInterfaceParams params;
  const SetupInterfacePage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SetupSelector(
      title: l10n.prototypeXrayOutboundInterface,
      description: l10n.prototypeInterfaceSelectionNotice,
      selected: params.selected,
      choices: [
        for (final item in params.interfaces)
          _Choice(
            item.name,
            item.name,
            [
              if (item.currentInternet) l10n.prototypeCurrentInternetInterface,
              ...item.addresses,
            ].join(' · '),
          ),
      ],
    );
  }
}

class SetupRegionPage extends StatelessWidget {
  final SetupRegionParams params;
  const SetupRegionPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _SetupSelector(
      title: l10n.prototypeChooseCountryRegion,
      description: l10n.prototypeRegionPurpose,
      selected: params.selected,
      searchLabel: l10n.prototypeRegionSearch,
      choices: [
        for (final code in params.codes)
          _Choice(code, setupRegionLabel(l10n, code), code),
      ],
    );
  }
}

class _Choice {
  final String id;
  final String label;
  final String description;
  const _Choice(this.id, this.label, this.description);
}

class _ChoiceState {
  final String selected;
  final List<_Choice> choices;
  const _ChoiceState(this.selected, this.choices);
}

class _ChoiceController extends PageCubit<_ChoiceState> {
  final List<_Choice> _all;
  _ChoiceController(List<_Choice> choices, String selected)
    : _all = choices,
      super(_ChoiceState(selected, choices));

  void select(String id) => emit(_ChoiceState(id, state.choices));
  bool get canSave => _all.any((choice) => choice.id == state.selected);
  void search(String text) {
    final search = text.trim().toLowerCase();
    emit(
      _ChoiceState(
        state.selected,
        _all
            .where(
              (choice) =>
                  '${choice.label} ${choice.id}'.toLowerCase().contains(search),
            )
            .toList(),
      ),
    );
  }

  void cancel(BuildContext context) => context.pop();
  void save(BuildContext context) => context.pop(state.selected);
}

class _SetupSelector extends StatelessWidget {
  final String title;
  final String description;
  final String selected;
  final String? searchLabel;
  final List<_Choice> choices;
  const _SetupSelector({
    required this.title,
    required this.description,
    required this.selected,
    required this.choices,
    this.searchLabel,
  });

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => _ChoiceController(choices, selected),
    child: BlocBuilder<_ChoiceController, _ChoiceState>(
      builder: (context, state) {
        final l10n = AppLocalizations.of(context)!;
        final controller = context.read<_ChoiceController>();
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: SafeArea(
            child: SettingsPageScroll(
              desktopMaxWidth: 760,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(description),
                  if (searchLabel != null) ...[
                    const SizedBox(height: 20),
                    TextField(
                      decoration: InputDecoration(labelText: searchLabel),
                      onChanged: controller.search,
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (state.choices.isEmpty)
                    Text(
                      searchLabel == null
                          ? l10n.prototypeTemporarilyUnavailable
                          : l10n.prototypeNoRegionsFound,
                    ),
                  for (final choice in state.choices)
                    SettingsChoiceRow(
                      title: choice.label,
                      description: choice.description,
                      selected: state.selected == choice.id,
                      onTap: () => controller.select(choice.id),
                    ),
                ],
              ),
            ),
          ),
          bottomNavigationBar: PageActionBar(
            children: [
              ShadButton.outline(
                onPressed: () => controller.cancel(context),
                child: Text(l10n.prototypeCancel),
              ),
              ShadButton(
                onPressed: controller.canSave
                    ? () => controller.save(context)
                    : null,
                child: Text(l10n.prototypeDone),
              ),
            ],
          ),
        );
      },
    ),
  );
}
