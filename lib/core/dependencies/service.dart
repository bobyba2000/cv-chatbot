import 'package:chatbot_cv/core/dependencies/app.dart';
import 'package:chatbot_cv/services/chatbot.dart';

class ServiceDependencies {
  static void init() {
    AppDependencies.injector.registerFactory(() => ChatbotService());
  }
}
