import 'package:flutter/material.dart';
import 'package:onexray/pages/theme/color.dart';
import 'package:onexray/pages/theme/font.dart';
import 'package:onexray/pages/theme/layout.dart';
import 'package:onexray/pages/widget/page_action_bar.dart';

/// Small setup forms fill the viewport but still scroll on a short screen or
/// with a larger system text size. Long selector lists use slivers instead.
class SetupBody extends StatelessWidget {
  const SetupBody({super.key, required this.children, this.top = 48});

  final List<Widget> children;
  final double top;

  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: mobile ? 620 : 760),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, top, 24, mobile ? 28 : 36),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SetupFooter extends StatelessWidget {
  const SetupFooter({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => PageActionBar(
    horizontalPadding: 24,
    verticalPadding: 16,
    spacing: 14,
    children: children,
  );
}

class SetupActionButton extends StatelessWidget {
  const SetupActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.outline = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool outline;

  @override
  Widget build(BuildContext context) {
    final palette = ColorManager.palette(context);
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 46)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      textStyle: WidgetStatePropertyAll(AppTypography.setupAction),
      backgroundColor: outline
          ? null
          : WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? palette.border.withValues(alpha: .7)
                  : null,
            ),
      foregroundColor: outline
          ? null
          : WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.disabled)
                  ? palette.mutedForeground.withValues(alpha: .7)
                  : null,
            ),
    );
    final text = Text(label, textAlign: TextAlign.center);
    return outline
        ? OutlinedButton(onPressed: onPressed, style: style, child: text)
        : FilledButton(onPressed: onPressed, style: style, child: text);
  }
}

class SetupPoint extends StatelessWidget {
  const SetupPoint({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final mobile =
        MediaQuery.sizeOf(context).width <= AppLayout.mobileBreakpoint;
    final palette = ColorManager.palette(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 23, color: palette.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style:
                (mobile
                        ? AppTypography.setupPoint
                        : AppTypography.setupDesktopPoint)
                    .copyWith(color: palette.mutedStrong),
          ),
        ),
      ],
    );
  }
}

class SetupError extends StatelessWidget {
  const SetupError({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Semantics(
      liveRegion: true,
      child: Text(
        text,
        style: AppTypography.setupError.copyWith(
          color: ColorManager.palette(context).destructive,
        ),
      ),
    ),
  );
}
