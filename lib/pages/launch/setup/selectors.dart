import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/launch/setup/widgets.dart';
import 'package:onexray/pages/mixin/page_cubit.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/service/tun_settings/interface.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class SetupInterfaceParams {
  final List<OutboundInterfaceOption> interfaces;
  final String selected;
  const SetupInterfaceParams(this.interfaces, this.selected);
}

class SetupRegionParams {
  final List<String> codes;
  final String selected;
  const SetupRegionParams(this.codes, this.selected);
}

String setupRegionLabel(AppLocalizations l10n, String code) =>
    l10n.countryRegionName(code.toUpperCase());

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

  void select(String id) {
    if (id != state.selected) emit(_ChoiceState(id, state.choices));
  }

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
  void save(BuildContext context) {
    if (canSave) context.pop(state.selected);
  }
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
        final palette = ColorManager.palette(context);
        final mobile =
            MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
        return Scaffold(
          appBar: mobile
              ? null
              : AppBar(
                  leading: IconButton(
                    tooltip: l10n.prototypeBack,
                    onPressed: () => controller.cancel(context),
                    icon: const Icon(LucideIcons.arrowLeftDir),
                  ),
                  title: Text(title),
                ),
          body: SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.setupContentMaxWidth,
                ),
                child: CustomScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        mobile ? 24 : 0,
                        mobile ? 56 : 24,
                        mobile ? 24 : 0,
                        28,
                      ),
                      sliver: SliverMainAxisGroup(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (mobile) ...[
                                  Row(
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            controller.cancel(context),
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          minimumSize: const Size(0, 38),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          textStyle: AppTypography.control,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              LucideIcons.arrowLeftDir,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(l10n.prototypeBack),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          title,
                                          style: AppTypography.setupChildTitle,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    description,
                                    style: AppTypography.setupSelectorDetail
                                        .copyWith(
                                          color: palette.mutedForeground,
                                        ),
                                  ),
                                  const SizedBox(height: 22),
                                ],
                                if (searchLabel != null) ...[
                                  TextField(
                                    style: AppTypography.setupSearch,
                                    onChanged: controller.search,
                                    decoration: InputDecoration(
                                      hintText: searchLabel,
                                      hintStyle: AppTypography.setupSearch
                                          .copyWith(
                                            color: palette.mutedForeground,
                                          ),
                                      prefixIcon: Icon(
                                        LucideIcons.search,
                                        size: 19,
                                        color: palette.mutedForeground,
                                      ),
                                      prefixIconConstraints:
                                          const BoxConstraints(
                                            minWidth: 44,
                                            minHeight: 46,
                                          ),
                                      contentPadding:
                                          const EdgeInsetsDirectional.fromSTEB(
                                            0,
                                            13,
                                            14,
                                            13,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.card,
                                        ),
                                        borderSide: BorderSide(
                                          color: palette.borderStrong,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppRadii.card,
                                        ),
                                        borderSide: BorderSide(
                                          color: palette.borderStrong,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                                if (state.choices.isEmpty)
                                  Text(
                                    searchLabel == null
                                        ? l10n.prototypeTemporarilyUnavailable
                                        : l10n.prototypeNoRegionsFound,
                                    style: AppTypography.setupSelectorDetail
                                        .copyWith(
                                          color: palette.mutedForeground,
                                        ),
                                  ),
                              ],
                            ),
                          ),
                          SliverList.builder(
                            itemCount: state.choices.length,
                            itemBuilder: (context, index) {
                              final choice = state.choices[index];
                              final selected = state.selected == choice.id;
                              final radius = BorderRadius.vertical(
                                top: index == 0
                                    ? const Radius.circular(AppRadii.card)
                                    : Radius.zero,
                                bottom: index == state.choices.length - 1
                                    ? const Radius.circular(AppRadii.card)
                                    : Radius.zero,
                              );
                              return Semantics(
                                selected: selected,
                                inMutuallyExclusiveGroup: true,
                                child: Material(
                                  color: selected
                                      ? palette.selectedSurface
                                      : palette.card,
                                  borderRadius: radius,
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: () => controller.select(choice.id),
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        minHeight: 68,
                                      ),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        borderRadius: radius,
                                        border: Border(
                                          left: BorderSide(
                                            color: palette.border,
                                          ),
                                          right: BorderSide(
                                            color: palette.border,
                                          ),
                                          bottom: BorderSide(
                                            color: palette.border,
                                          ),
                                          top: index == 0
                                              ? BorderSide(
                                                  color: palette.border,
                                                )
                                              : BorderSide.none,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          ShadRadioGroup<String>(
                                            initialValue: state.selected,
                                            onChanged: (value) {
                                              if (value != null &&
                                                  value != state.selected) {
                                                controller.select(value);
                                              }
                                            },
                                            items: [
                                              ShadRadio<String>(
                                                value: choice.id,
                                                size: 16,
                                                circleSize: 10,
                                                radioPadding: EdgeInsets.zero,
                                                decoration: ShadDecoration(
                                                  border: ShadBorder.all(
                                                    color: selected
                                                        ? palette.primary
                                                        : palette.borderStrong,
                                                    width: 1,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              children: [
                                                Text(
                                                  choice.label,
                                                  style: AppTypography
                                                      .setupSelectorTitle,
                                                ),
                                                if (choice
                                                    .description
                                                    .isNotEmpty) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    choice.description,
                                                    style: AppTypography
                                                        .setupSelectorDetail
                                                        .copyWith(
                                                          color: palette
                                                              .mutedForeground,
                                                        ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          bottomNavigationBar: SetupFooter(
            children: [
              SetupActionButton(
                label: l10n.prototypeCancel,
                outline: true,
                onPressed: () => controller.cancel(context),
              ),
              SetupActionButton(
                label: l10n.prototypeDone,
                onPressed: controller.canSave
                    ? () => controller.save(context)
                    : null,
              ),
            ],
          ),
        );
      },
    ),
  );
}
