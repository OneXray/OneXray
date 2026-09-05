import 'package:flutter/material.dart';

/// Reports visibility for a page inside an Advanced secondary tab.
///
/// The native [TabController] is navigation state. Page business state remains
/// in Bloc; this widget only translates tab and route lifecycle into a boolean.
class AdvancedTabVisibility extends StatefulWidget {
  const AdvancedTabVisibility({
    super.key,
    required this.tabIndex,
    required this.onChanged,
    required this.child,
  });

  final int tabIndex;
  final ValueChanged<bool> onChanged;
  final Widget child;

  @override
  State<AdvancedTabVisibility> createState() => _AdvancedTabVisibilityState();
}

class _AdvancedTabVisibilityState extends State<AdvancedTabVisibility> {
  TabController? _tabs;
  bool _routeVisible = false;
  bool? _reported;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tabs = DefaultTabController.maybeOf(context);
    if (_tabs != tabs) {
      _tabs?.removeListener(_tabChanged);
      _tabs = tabs;
      _tabs?.addListener(_tabChanged);
    }
    _routeVisible =
        TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    _scheduleReport();
  }

  @override
  void didUpdateWidget(AdvancedTabVisibility oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onChanged != widget.onChanged) {
      if (_reported == true) oldWidget.onChanged(false);
      _reported = null;
    }
    _scheduleReport();
  }

  void _scheduleReport() {
    if (_scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (!mounted) return;
      _report();
    });
  }

  void _tabChanged() {
    if (!mounted) return;
    _report();
  }

  void _report() {
    final visible =
        _routeVisible && (_tabs == null || _tabs!.index == widget.tabIndex);
    if (visible == _reported) return;
    _reported = visible;
    widget.onChanged(visible);
  }

  @override
  void dispose() {
    _tabs?.removeListener(_tabChanged);
    if (_reported == true) widget.onChanged(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
