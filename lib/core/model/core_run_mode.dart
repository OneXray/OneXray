enum CoreRunMode {
  tun("tun"),
  proxy("proxy");

  const CoreRunMode(this.name);

  final String name;

  @override
  String toString() => name;
}
