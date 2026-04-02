import 'package:chatbot_cv/presentation/chatbot/page.dart';
import 'package:flutter/material.dart';

class AppRouter {
  static const String homeRoute = '/';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case homeRoute:
      default:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const CvChatbotPage(),
        );
    }
  }
}
