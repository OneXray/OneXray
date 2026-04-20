import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/home/xray/setting/inbound_ping/controller.dart';
import 'package:onexray/pages/home/xray/setting/inbound_ping/params.dart';
import 'package:onexray/pages/widget/section.dart';
import 'package:onexray/pages/widget/text_row.dart';

class InboundPingPage extends StatelessWidget {
  final InboundPingParams params;

  const InboundPingPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InboundPingController(params),
      child: BlocBuilder<InboundPingController, InboundPingCubitState>(
        builder: (context, state) {
          final controller = context.read<InboundPingController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(AppLocalizations.of(context)!.inboundPingPageTitle),
            ),
            body: SafeArea(child: _body(context, controller, state)),
          );
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    InboundPingController controller,
    InboundPingCubitState state,
  ) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _listenSection(context, controller, state),
            _tagSection(context, controller, state),
          ],
        ),
      ),
    );
  }

  Widget _listenSection(
    BuildContext context,
    InboundPingController controller,
    InboundPingCubitState state,
  ) {
    return SectionView(
      title: "",
      child: Column(
        children: [
          TextRow(
            title: AppLocalizations.of(context)!.inboundPingPageListen,
            detail: state.httpState.listen,
          ),
          TextRow(
            title: AppLocalizations.of(context)!.inboundPingPagePort,
            detail: state.httpState.port,
          ),
          TextRow(
            title: AppLocalizations.of(context)!.inboundPingPageProtocol,
            detail: state.httpState.protocol.name,
          ),
        ],
      ),
    );
  }

  Widget _tagSection(
    BuildContext context,
    InboundPingController controller,
    InboundPingCubitState state,
  ) {
    return SectionView(
      title: "",
      child: Column(
        children: [
          TextRow(
            title: AppLocalizations.of(context)!.inboundPingPageTag,
            detail: state.httpState.tag.name,
          ),
        ],
      ),
    );
  }
}
