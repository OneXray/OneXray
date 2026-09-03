import 'package:flutter/material.dart';

/// Retained root tabs stay mounted. A page is visible only while its branch is
/// active and no full page is above it in that branch's Navigator.
class PageVisibility extends StatefulWidget {
  const PageVisibility({
    super.key,
    required this.onChanged,
    required this.child,
  });

  final ValueChanged<bool> onChanged;
  final Widget child;

  @override
  State<PageVisibility> createState() => _PageVisibilityState();
}

class _PageVisibilityState extends State<PageVisibility> {
  bool _visible = false;
  bool? _reported;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _visible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    if (_scheduled || _visible == _reported) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted || _visible == _reported) return;
      _reported = _visible;
      widget.onChanged(_visible);
    });
  }

  @override
  void dispose() {
    if (_reported == true) widget.onChanged(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
