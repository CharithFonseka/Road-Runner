import 'package:flutter/material.dart';

// Road Runner — application entry point.
// Owner: Praveen (integration shell) / Tharushi (screens & theme)

void main() {
  runApp(const RoadRunnerApp());
}

/// Root application widget.
class RoadRunnerApp extends StatelessWidget {
  const RoadRunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Road Runner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFD9622B),
        ),
        useMaterial3: true,
      ),
      home: const RoadRunnerShellPage(),
    );
  }
}

/// Integration shell screen displayed until feature screens are connected.
class RoadRunnerShellPage extends StatelessWidget {
  const RoadRunnerShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Road Runner'),
      ),
      body: const Center(
        child: Text(
          'Road Runner ready for integration.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
