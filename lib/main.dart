import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/screens.dart';
import 'services/services.dart';
import 'splash/splash_screen.dart';
import 'widgets/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.load();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  runApp(const BharosoApp());
}

class BharosoApp extends StatefulWidget {
  const BharosoApp({super.key});

  @override
  State<BharosoApp> createState() => _BharosoAppState();
}

class _BharosoAppState extends State<BharosoApp> {
  bool _splashDone = false;
  final ThemeData _theme = buildTheme(); // built once

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bharoso',
      theme: _theme,
      builder: (context, child) => AppScope(
        builder: (_) => Directionality(
          textDirection: app.lang == 0 ? TextDirection.ltr : TextDirection.rtl,
          child: child!,
        ),
      ),
      home: _splashDone
          ? AppScope(builder: (_) => app.consent ? const Shell() : const ConsentScreen())
          : AppSplash(onDone: () => setState(() => _splashDone = true)),
    );
  }
}