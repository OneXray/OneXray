import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/shared/widgets/button_progress.dart';
import 'package:onexray/service/shared/event_bus/service.dart';
import 'package:onexray/service/shared/event_bus/state.dart';

/// Shared activity updates presentation only, never page-wide availability.
class AppActivityBuilder extends StatelessWidget {
  const AppActivityBuilder({super.key, required this.builder});

  final Widget Function(BuildContext, AppEventBusState) builder;

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<AppEventBus, AppEventBusState>(
        bloc: AppEventBus.instance,
        buildWhen: (previous, next) =>
            previous.pinging != next.pinging ||
            previous.downloading != next.downloading,
        builder: builder,
      );
}

/// Read-only pages can show background work without making Save look busy.
class AppActivityIndicator extends StatelessWidget {
  const AppActivityIndicator({
    super.key,
    this.pinging = true,
    this.downloading = true,
  });

  final bool pinging;
  final bool downloading;

  @override
  Widget build(BuildContext context) => AppActivityBuilder(
    builder: (context, activity) {
      final l = AppLocalizations.of(context)!;
      final labels = [
        if (pinging && activity.pinging) l.prototypeSpeedTest,
        if (downloading && activity.downloading) l.prototypeDataUpdates,
      ];
      return labels.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Tooltip(
                message: labels.join(' · '),
                child: const ButtonProgressIndicator(),
              ),
            );
    },
  );
}
