import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/inbound_sniffing/controller.dart';
import 'package:onexray/pages/home/xray/setting/inbound_sniffing/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';
import 'package:onexray/service/xray/setting/inbounds_state.dart';

class InboundSniffingPage extends StatelessWidget {
  final InboundSniffingParams params;

  const InboundSniffingPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InboundSniffingController(params),
      child: BlocBuilder<InboundSniffingController, InboundSniffingCubitState>(
        builder: (context, state) {
          final controller = context.read<InboundSniffingController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(
                AppLocalizations.of(context)!.inboundSniffingPageTitle,
              ),
            ),
            body: SafeArea(child: _body(context, controller, state)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    InboundSniffingController controller,
    InboundSniffingCubitState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: ResponsiveContent(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _enableSection(context, controller, state),
                    _routeOnlySection(context, controller, state),
                    _metadataOnlySection(context, controller, state),
                    _destOverrideSection(context, controller, state),
                    _domainsExcludedSection(context, controller, state),
                    _ipsExcludedSection(context, controller, state),
                  ],
                ),
              ),
            ),
            _bottomButton(context, controller),
          ],
        ),
      ),
    );
  }

  Widget _enableSection(
    BuildContext context,
    InboundSniffingController controller,
    InboundSniffingCubitState state,
  ) {
    return SettingSection(
      title: "",
      children: [
        SwitchSettingRow(
          title: AppLocalizations.of(context)!.switchEnabled,
          value: state.sniffingState.enabled,
          onChanged: (value) => controller.updateEnabled(value),
        ),
      ],
    );
  }

  Widget _routeOnlySection(
    BuildContext context,
    InboundSniffingController controller,
    InboundSniffingCubitState state,
  ) {
    return SettingSection(
      title: "",
      children: [
        SwitchSettingRow(
          title: AppLocalizations.of(context)!.switchRouteOnly,
          value: state.sniffingState.routeOnly,
          onChanged: (value) => controller.updateRouteOnly(value),
        ),
      ],
    );
  }

  Widget _metadataOnlySection(
    BuildContext context,
    InboundSniffingController controller,
    InboundSniffingCubitState state,
  ) {
    return SettingSection(
      title: "",
      children: [
        SwitchSettingRow(
          title: AppLocalizations.of(context)!.inboundSniffingPageMetadataOnly,
          value: state.sniffingState.metadataOnly,
          onChanged: (value) => controller.updateMetadataOnly(value),
        ),
      ],
    );
  }

  Widget _destOverrideSection(
    BuildContext context,
    InboundSniffingController controller,
    InboundSniffingCubitState state,
  ) {
    final children = InboundSniffingDestOverride.values.map((value) {
      return FilterChip(
        label: Text(value.name),
        selected: state.sniffingState.destOverride.contains(value),
        onSelected: (bool selected) =>
            controller.updateDestOverride(selected, value),
      );
    }).toList();

    return SettingSection(
      title: AppLocalizations.of(context)!.inboundSniffingPageDestOverride,
      separated: false,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Wrap(spacing: 5.0, runSpacing: 5.0, children: children),
          ),
        ),
      ],
    );
  }

  Widget _domainsExcludedSection(
    BuildContext context,
    InboundSniffingController controller,
    InboundSniffingCubitState state,
  ) {
    final domainsExcludedViews = state.sniffingState.domainsExcluded
        .mapIndexed(
          (index, host) => TextFieldActionSettingRow(
            controller: controller.domainsExcludedControllers[index],
            label: AppLocalizations.of(
              context,
            )!.inboundSniffingPageDomainsExcluded,
            hintText: AppLocalizations.of(
              context,
            )!.inboundSniffingPageDomainsExcludedExample,
            trailing: IconButton(
              onPressed: () => controller.deleteDomainsExcluded(context, index),
              icon: const Icon(Icons.delete),
            ),
          ),
        )
        .toList();
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: AppLocalizations.of(
            context,
          )!.inboundSniffingPageDomainsExcluded,
          trailing: IconButton(
            onPressed: () => controller.appendDomainsExcluded(),
            icon: const Icon(Icons.add),
          ),
        ),
        ...domainsExcludedViews,
      ],
    );
  }

  Widget _ipsExcludedSection(
    BuildContext context,
    InboundSniffingController controller,
    InboundSniffingCubitState state,
  ) {
    final ipsExcludedViews = state.sniffingState.ipsExcluded
        .mapIndexed(
          (index, host) => TextFieldActionSettingRow(
            controller: controller.ipsExcludedControllers[index],
            label: AppLocalizations.of(context)!.inboundSniffingPageIpsExcluded,
            hintText: AppLocalizations.of(
              context,
            )!.inboundSniffingPageIpsExcludedExample,
            trailing: IconButton(
              onPressed: () => controller.deleteIpsExcluded(context, index),
              icon: const Icon(Icons.delete),
            ),
          ),
        )
        .toList();
    return SettingSection(
      title: "",
      children: [
        SettingRow(
          title: AppLocalizations.of(context)!.inboundSniffingPageIpsExcluded,
          trailing: IconButton(
            onPressed: () => controller.appendIpsExcluded(),
            icon: const Icon(Icons.add),
          ),
        ),
        ...ipsExcludedViews,
      ],
    );
  }

  Widget _bottomButton(
    BuildContext context,
    InboundSniffingController controller,
  ) {
    return BottomView(
      child: Row(
        children: [
          Expanded(
            child: PrimaryBottomButton(
              title: AppLocalizations.of(context)!.buttonSave,
              callback: () => controller.save(context),
            ),
          ),
        ],
      ),
    );
  }
}
