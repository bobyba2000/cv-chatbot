import 'package:chatbot_cv/config/router/router.dart';
import 'package:chatbot_cv/core/dependencies/app.dart';
import 'package:chatbot_cv/core/theme/theme.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppDependencies.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CV Chatbot Assistant',
      theme: AppTheme.lightTheme,
      initialRoute: AppRouter.homeRoute,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
