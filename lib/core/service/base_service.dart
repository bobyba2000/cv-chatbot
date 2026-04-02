import 'package:flutter/material.dart';

import '../dependencies/app.dart';
import 'rest_utils.dart';

class BaseService {
  @protected
  final rest = AppDependencies.injector.get<RestUtils>();
}
