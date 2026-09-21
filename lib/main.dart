import 'package:demo/home/demo_home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PluginDemoApp());
}

class PluginDemoApp extends StatelessWidget {
  const PluginDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '插件测试中心',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF006B5B)),
          useMaterial3: true,
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        home: DemoHomePage(),
      ),
    );
  }
}

/// Backwards-compatible app name retained for existing NFC widget consumers.
class NdefDemoApp extends PluginDemoApp {
  const NdefDemoApp({super.key});
}
