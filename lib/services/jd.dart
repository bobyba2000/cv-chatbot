import 'package:chatbot_cv/core/service/base_service.dart';
import 'package:chatbot_cv/core/service/rest_utils.dart';
import 'package:chatbot_cv/core/service/result.dart';

class _JdPath {
  static const String jds = '/api/jds';
}

class JdService extends BaseService {
  Future<Result<List<Map<String, dynamic>>>> getJds() async {
    final response = await rest.sendRawRequest(Method.get, _JdPath.jds);
    if (!response.isSuccessful) {
      return Failed<List<Map<String, dynamic>>>(
        (response as Failed<Map<String, dynamic>>).errorCode ?? '500',
        response.toString(),
      );
    }

    final payload = response.data;
    final rows = payload?['data'];
    if (rows is! List) {
      return Failed<List<Map<String, dynamic>>>(
        '500',
        'Unexpected JD response format',
      );
    }

    return Success<List<Map<String, dynamic>>>(
      rows
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
    );
  }
}
