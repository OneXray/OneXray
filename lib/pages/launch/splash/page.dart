import 'package:flutter/material.dart';
import 'package:onexray/pages/launch/init.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold();
  }

  @override
  void initState() {
    initRouter(context);
    super.initState();
  }
}
