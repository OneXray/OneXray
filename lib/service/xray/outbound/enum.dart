import 'package:collection/collection.dart';

enum VMessSecurity {
  aes128gcm("aes-128-gcm"),
  chacha20poly1305("chacha20-poly1305"),
  auto("auto");

  const VMessSecurity(this.name);

  final String name;

  @override
  String toString() => name;

  static VMessSecurity? fromString(String name) =>
      VMessSecurity.values.firstWhereOrNull((value) => value.name == name);
}

enum ShadowsocksMethod {
  blake3aes128gcm2022("2022-blake3-aes-128-gcm"),
  blake3aes256gcm2022("2022-blake3-aes-256-gcm"),
  blake3chacha20poly13052022("2022-blake3-chacha20-poly1305"),
  aes128gcm("aes-128-gcm"),
  aes256gcm("aes-256-gcm"),
  chacha20poly1305("chacha20-poly1305"),
  xchacha20poly1305("xchacha20-poly1305");

  const ShadowsocksMethod(this.name);

  final String name;

  @override
  String toString() => name;

  static ShadowsocksMethod? fromString(String name) =>
      ShadowsocksMethod.values.firstWhereOrNull((value) => value.name == name);
}
