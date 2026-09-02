import 'package:flutter/material.dart';

/// A modal selection surface, separate from full-page child navigation.
Future<T?> showChoiceDialog<T>(BuildContext context, WidgetBuilder builder) {
  if (MediaQuery.sizeOf(context).width < 700) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: builder(context),
      ),
    );
  }
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: builder(context),
      ),
    ),
  );
}
