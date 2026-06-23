import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/core/xray/setting/fake_dns/controller.dart';
import 'package:onexray/pages/core/xray/setting/fake_dns/params.dart';
import 'package:onexray/pages/widget/bottom_button.dart';
import 'package:onexray/pages/widget/bottom_view.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:onexray/pages/widget/setting_row.dart';

class FakeDnsPage extends StatelessWidget {
  final FakeDnsParams params;

  const FakeDnsPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FakeDnsController(params),
      child: BlocBuilder<FakeDnsController, FakeDnsCubitState>(
        builder: (context, state) {
          final controller = context.read<FakeDnsController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.fakeDnsPageTitle),
            ),
            body: SafeArea(child: _body(context, controller)),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, FakeDnsController controller) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: ResponsiveContent(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _ipv4Section(context, controller),
                    _ipv6Section(context, controller),
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

  Widget _ipv4Section(BuildContext context, FakeDnsController controller) {
    return SettingSection(
      title: AppLocalizations.of(context)!.fakeDnsPageIPv4,
      children: [
        _ipPool(context, controller.ipv4IpPoolController),
        _poolSize(context, controller.ipv4PoolSizeController),
      ],
    );
  }

  Widget _ipv6Section(BuildContext context, FakeDnsController controller) {
    return SettingSection(
      title: AppLocalizations.of(context)!.fakeDnsPageIPv6,
      children: [
        _ipPool(context, controller.ipv6IpPoolController),
        _poolSize(context, controller.ipv6PoolSizeController),
      ],
    );
  }

  Widget _ipPool(BuildContext context, TextEditingController controller) {
    return TextFieldSettingRow(
      controller: controller,
      label: AppLocalizations.of(context)!.fakeDnsPageIpPool,
      hintText: AppLocalizations.of(context)!.fakeDnsPageIpPool,
    );
  }

  Widget _poolSize(BuildContext context, TextEditingController controller) {
    return TextFieldSettingRow(
      controller: controller,
      keyboardType: TextInputType.number,
      label: AppLocalizations.of(context)!.fakeDnsPagePoolSize,
      hintText: AppLocalizations.of(context)!.fakeDnsPagePoolSize,
    );
  }

  Widget _bottomButton(BuildContext context, FakeDnsController controller) {
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
