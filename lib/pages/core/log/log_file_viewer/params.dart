class LogFileViewerParams {
  final String title;
  final String path;
  final bool systemExtension;
  final bool access;

  const LogFileViewerParams({
    required this.title,
    required this.path,
    this.systemExtension = false,
    this.access = true,
  });
}
