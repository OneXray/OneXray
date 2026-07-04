import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/home/component/nodes/controller.dart';
import 'package:onexray/pages/home/component/nodes/view.dart';
import 'package:onexray/pages/home/outbound_select/params.dart';

class OutboundSelectPage extends StatelessWidget {
  final OutboundSelectParams params;

  const OutboundSelectPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.outboundSelectPageTitle),
      ),
      body: SafeArea(
        child: HomeNodeView(
          queryType: HomeNodeQueryType.outboundOnly,
          showSearch: true,
          selectedId: params.selectedId,
          onSelect: (config) => context.pop(config),
        ),
      ),
    );
  }
}
