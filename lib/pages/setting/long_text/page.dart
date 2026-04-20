import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/core/tools/platform.dart';
import 'package:onexray/pages/global/constants.dart';
import 'package:onexray/pages/setting/long_text/controller.dart';
import 'package:onexray/pages/setting/long_text/params.dart';

class LongTextPage extends StatelessWidget {
  final LongTextParams params;

  const LongTextPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LongTextController(params),
      child: BlocBuilder<LongTextController, LongTextState>(
        builder: (context, state) {
          final controller = context.read<LongTextController>();
          return Scaffold(
            appBar: AppBar(
              title: Text(state.title),
              actions: [
                if (!AppPlatform.isLinux)
                  IconButton(
                    onPressed: () => controller.shareFile(context),
                    icon: Icon(Icons.share),
                  ),
              ],
            ),
            body: SafeArea(child: SelectionArea(child: _body(context, state))),
          );
        },
      ),
    );
  }

  Widget _body(BuildContext context, LongTextState state) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontSize: GlobalConstants.bodyFontSize),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(20.0),
          child: Text(state.text),
        ),
      ),
    );
  }
}
