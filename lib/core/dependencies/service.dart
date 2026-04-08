import 'package:chatbot_cv/core/dependencies/app.dart';
import 'package:chatbot_cv/services/chatbot.dart';
import 'package:chatbot_cv/services/jd.dart';

class ServiceDependencies {
  static void init() {
    AppDependencies.injector.registerFactory(() => ChatbotService());
    AppDependencies.injector.registerFactory(() => JdService());
  }
}
