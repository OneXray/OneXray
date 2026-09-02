import 'package:flutter_test/flutter_test.dart';
import 'package:onexray/core/model/geo_data_type.dart';
import 'package:onexray/service/geo_data/model.dart';

void main() {
  test(
    'new names use one canonical extension without rewriting existing rows',
    () {
      expect(GeoDataInput.canonicalFileName(' rules '), 'rules.dat');
      expect(GeoDataInput.canonicalFileName('rules.dat'), 'rules.dat');
      expect(GeoDataInput.canonicalFileName('Rules.DAT'), 'Rules.dat');
      expect(
        const GeoDataInput(
          fileName: 'rules.dat',
          type: GeoDataType.domain,
          url: 'https://example.com/rules.dat',
        ).name,
        'rules',
      );
    },
  );

  test(
    'custom names cannot collide with defaults or escape the data directory',
    () {
      for (final value in [
        '',
        ' ',
        'geoip',
        'GEOSITE.DAT',
        '.',
        '..',
        '../x',
        r'..\x',
        '/tmp/rules',
        r'C:\rules',
        '.hidden',
        'rules.',
        'rules .dat',
        'CON.dat',
        'lpt1.dat',
        'x\u0000y',
        'rules?.dat',
      ]) {
        expect(
          () => GeoDataInput.canonicalFileName(value),
          throwsFormatException,
          reason: value,
        );
      }
    },
  );

  test('download sources require credential-free HTTPS URLs', () {
    expect(
      GeoDataInput.httpsUri('https://example.com/rules.dat?version=2').host,
      'example.com',
    );
    for (final value in [
      'http://example.com/rules.dat',
      'file:///rules.dat',
      'https://',
      'https://user:password@example.com/rules.dat',
      'https://example.com/rules.dat#fragment',
      ' https://example.com/rules.dat',
    ]) {
      expect(() => GeoDataInput.httpsUri(value), throwsFormatException);
    }
  });
}
