/// Menu content independent of native handles and event delivery.
class TrayMenuEntry {
  final String? key;
  final String label;
  final bool disabled;
  final bool? checked;
  final List<TrayMenuEntry>? children;
  final bool isSeparator;

  const TrayMenuEntry({
    this.key,
    this.label = '',
    this.disabled = false,
    this.checked,
    this.children,
  }) : isSeparator = false;

  const TrayMenuEntry.separator()
    : key = null,
      label = '',
      disabled = true,
      checked = null,
      children = null,
      isSeparator = true;
}
