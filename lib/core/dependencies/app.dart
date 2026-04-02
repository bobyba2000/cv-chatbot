import 'package:chatbot_cv/core/dependencies/model.dart';
import 'package:chatbot_cv/core/dependencies/service.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/web.dart';

import '../service/rest_utils.dart';

class AppDependencies {
  AppDependencies._();
  static GetIt injector = GetIt.instance;
  static Future<void> init() async {
    if (!injector.isRegistered<Logger>()) {
      injector.registerSingleton(Logger());
    }
    if (!injector.isRegistered<RestUtils>()) {
      injector.registerSingleton(
        RestUtils(
          kDebugMode ? 'localhost:4000' : 'vco-saas-d4b4443d487b.herokuapp.com',
        ),
      );
    }
    ServiceDependencies.init();
    ModelDependencies.init();
  }
}
