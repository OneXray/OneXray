import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/desktop_startup/windows_adapter.dart';

void main() {
  test('builds the Windows startup command without context arguments', () {
    expect(
      WindowsLaunchAtLoginAdapter.commandForExecutable(
        r'C:\Program Files\OneXray\OneXray.exe',
      ),
      r'"C:\Program Files\OneXray\OneXray.exe"',
    );
  });

  test('quotes embedded quotes and trailing backslashes', () {
    expect(
      WindowsLaunchAtLoginAdapter.quoteCommandLineArgument(
        'C:\\OneXray "Test"\\',
      ),
      '"C:\\OneXray \\"Test\\"\\\\"',
    );
  });
}
