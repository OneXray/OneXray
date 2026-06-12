import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:onexray/core/tools/logger.dart';
import 'package:onexray/pages/launch/init.dart';
import 'package:onexray/pages/main/url.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }

  @override
  void initState() {
    super.initState();
    _initRouter();
  }

  Future<void> _initRouter() async {
    try {
      await initRouter(context);
    } catch (e, stackTrace) {
      ygLogger("initRouter error: $e\n$stackTrace");
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: stackTrace,
          library: "OneXray launch",
          context: ErrorDescription("while initializing the launch router"),
        ),
      );
      if (mounted) {
        context.go(RouterPath.privacy);
      }
    }
  }
}
