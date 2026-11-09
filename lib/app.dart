import 'package:baller/ui/screens/title_screen.dart';
import 'package:baller/ui/theme/app_theme.dart';
import 'package:flutter/material.dart';

class BallerApp extends StatelessWidget {
  const BallerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baller',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const TitleScreen(),
    );
  }
}
