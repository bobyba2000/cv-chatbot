import 'package:chatbot_cv/core/service/base_service.dart';
import 'package:chatbot_cv/core/service/rest_utils.dart';
import 'package:chatbot_cv/core/service/result.dart';
import 'package:chatbot_cv/models/chat/model.dart';

class _ChatbotPath {
  static const String analyze = '/api/chatbot/analyze';
  static const String chat = '/api/chatbot/chat';
  static const String applyFixes = '/api/chatbot/apply-fixes';
}

class ChatbotService extends BaseService {
  Future<Result<Map<String, dynamic>>> analyzeCv({
    required List<int> cvBytes,
    required String fileName,
    required String jd,
  }) {
    return rest.sendMultipartRequest(
      _ChatbotPath.analyze,
      fileField: 'cv',
      fileBytes: cvBytes,
      filename: fileName,
      fields: {'jd': jd},
    );
  }

  Future<Result<Map<String, dynamic>>> chat({
    required String message,
    String? jd,
    required bool hasCv,
    String? sessionId,
  }) {
    return rest.sendRawRequest(
      Method.post,
      _ChatbotPath.chat,
      jsonData: {
        'message': message,
        'jd': jd,
        'has_cv': hasCv,
        'sessionId': sessionId,
      },
    );
  }

  Future<Result<Map<String, dynamic>>> applyFixes({
    required String sessionId,
    required String cvId,
    required List<CvHighlight> highlights,
  }) {
    return rest.sendRawRequest(
      Method.post,
      _ChatbotPath.applyFixes,
      jsonData: {
        'sessionId': sessionId,
        'cvId': cvId,
        'highlights': highlights.map((item) => item.toJson()).toList(),
      },
    );
  }
}
