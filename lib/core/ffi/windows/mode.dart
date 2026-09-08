enum WindowsMode { exe, msix }

const _configuredMode = String.fromEnvironment(
  'ONEXRAY_WINDOWS_MODE',
  defaultValue: 'exe',
);

WindowsMode get windowsBuildMode => switch (_configuredMode) {
  'exe' => WindowsMode.exe,
  'msix' => WindowsMode.msix,
  _ => throw UnsupportedError(
    'ONEXRAY_WINDOWS_MODE must be exe or msix: $_configuredMode',
  ),
};
