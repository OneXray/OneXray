import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:onexray/l10n/localizations/app_localizations.dart';
import 'package:onexray/pages/core/log/log_file_viewer/controller.dart';
import 'package:onexray/pages/core/log/log_file_viewer/params.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/widget/responsive_content.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class LogFileViewerPage extends StatelessWidget {
  final LogFileViewerParams params;

  const LogFileViewerPage({super.key, required this.params});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LogFileViewerController(params),
      child: const _LogFileViewerScaffold(),
    );
  }
}

class _LogFileViewerScaffold extends StatefulWidget {
  const _LogFileViewerScaffold();

  @override
  State<_LogFileViewerScaffold> createState() => _LogFileViewerScaffoldState();
}

class _LogFileViewerScaffoldState extends State<_LogFileViewerScaffold> {
  final _scrollController = ScrollController();
  var _autoScrolling = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LogFileViewerController, LogFileViewerPageState>(
      listenWhen: (previous, current) =>
          current.followTail &&
          (previous.lines.length != current.lines.length ||
              previous.followTail != current.followTail),
      listener: (_, _) => _scrollToBottom(),
      builder: (context, state) {
        final controller = context.read<LogFileViewerController>();
        return Scaffold(
          appBar: AppBar(title: Text(state.title)),
          body: SafeArea(
            child: Stack(
              children: [
                ResponsiveContent(
                  desktopMaxWidth: 1080,
                  child: SelectionArea(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        _handleScrollNotification(controller, notification);
                        return false;
                      },
                      child: _body(context, state),
                    ),
                  ),
                ),
                if (!state.followTail)
                  PositionedDirectional(
                    end: 18,
                    bottom: 18,
                    child: ShadButton(
                      height: 36,
                      onPressed: () {
                        controller.setFollowTail(true);
                        _scrollToBottom();
                      },
                      leading: const Icon(
                        LucideIcons.arrowDownToLine,
                        size: 16,
                      ),
                      child: Text(
                        AppLocalizations.of(
                          context,
                        )!.logFileViewerContinueFollowing,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, LogFileViewerPageState state) {
    if (!state.fileExists) {
      return Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.fileX,
                size: 36,
                color: ColorManager.secondaryText(context),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)!.logFileViewerFileNotExist,
                textAlign: TextAlign.center,
                style: AppTypography.supporting.copyWith(
                  color: ColorManager.secondaryText(context),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsetsDirectional.fromSTEB(22, 18, 22, 30),
      itemCount: state.lines.length + (state.truncated ? 1 : 0),
      itemBuilder: (context, index) {
        if (state.truncated && index == 0) {
          return _recentLogHint(context);
        }
        final lineIndex = state.truncated ? index - 1 : index;
        return Text(
          state.lines[lineIndex],
          style: AppTypography.code.copyWith(
            color: ColorManager.primaryText(context),
          ),
        );
      },
    );
  }

  Widget _recentLogHint(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 9),
      child: Text(
        AppLocalizations.of(context)!.logFileViewerShowingRecent,
        style: AppTypography.badge.copyWith(
          color: ColorManager.secondaryText(context),
        ),
      ),
    );
  }

  void _handleScrollNotification(
    LogFileViewerController controller,
    ScrollNotification notification,
  ) {
    if (_autoScrolling || notification is! ScrollUpdateNotification) {
      return;
    }
    if (notification.dragDetails == null) {
      return;
    }
    controller.setFollowTail(notification.metrics.extentAfter < 48);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _autoScrolling = true;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      _autoScrolling = false;
    });
  }
}
