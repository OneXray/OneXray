import 'package:flutter/material.dart';

/// Progress belongs to the action that started it; the label remains readable.
class ButtonProgress extends StatelessWidget {
  const ButtonProgress({super.key, required this.busy, required this.child});

  final bool busy;
  final Widget child;

  @override
  Widget build(BuildContext context) => busy
      ? Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ButtonProgressIndicator(),
            const SizedBox(width: 8),
            Flexible(child: child),
          ],
        )
      : child;
}

class ButtonProgressIndicator extends StatelessWidget {
  const ButtonProgressIndicator({super.key, this.size = 16});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CircularProgressIndicator(
      strokeWidth: 2,
      color: DefaultTextStyle.of(context).style.color,
    ),
  );
}
