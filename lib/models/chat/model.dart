enum ChatRole { user, bot }

class CvHighlight {
  const CvHighlight({
    required this.text,
    required this.problem,
    required this.suggestion,
  });

  factory CvHighlight.fromJson(Map<String, dynamic> json) {
    return CvHighlight(
      text: (json['text'] ?? '').toString(),
      problem: (json['problem'] ?? '').toString(),
      suggestion: (json['suggestion'] ?? '').toString(),
    );
  }
  final String text;
  final String problem;
  final String suggestion;

  Map<String, String> toJson() {
    return {'text': text, 'problem': problem, 'suggestion': suggestion};
  }
}

class MissingSkill {
  const MissingSkill({
    required this.skill,
    required this.reason,
    required this.suggestion,
  });

  factory MissingSkill.fromJson(Object? input) {
    if (input is String) {
      return MissingSkill(
        skill: input,
        reason: 'Often expected for roles in this area.',
        suggestion: 'Add a project or bullet showing hands-on use.',
      );
    }

    if (input is Map<String, dynamic>) {
      return MissingSkill(
        skill: (input['skill'] ?? '').toString(),
        reason: (input['reason'] ?? '').toString(),
        suggestion: (input['suggestion'] ?? '').toString(),
      );
    }

    return const MissingSkill(skill: '', reason: '', suggestion: '');
  }
  final String skill;
  final String reason;
  final String suggestion;
}

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.text,
    this.suggestions = const [],
    this.score,
    this.imageUrl,
    this.highlights = const [],
    this.missingSkills = const [],
    this.lowMatch = false,
    this.recommendations = const [],
    this.sessionId,
    this.cvId,
    this.isApplyingFixes = false,
    this.updatedPdfUrl,
  });
  static const Object _unset = Object();

  final ChatRole role;
  final String text;
  final List<String> suggestions;
  final int? score;
  final String? imageUrl;
  final List<CvHighlight> highlights;
  final List<MissingSkill> missingSkills;
  final bool lowMatch;
  final List<String> recommendations;
  final String? sessionId;
  final String? cvId;
  final bool isApplyingFixes;
  final String? updatedPdfUrl;

  ChatMessage copyWith({
    ChatRole? role,
    String? text,
    List<String>? suggestions,
    Object? score = _unset,
    Object? imageUrl = _unset,
    List<CvHighlight>? highlights,
    List<MissingSkill>? missingSkills,
    bool? lowMatch,
    List<String>? recommendations,
    Object? sessionId = _unset,
    Object? cvId = _unset,
    bool? isApplyingFixes,
    Object? updatedPdfUrl = _unset,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      text: text ?? this.text,
      suggestions: suggestions ?? this.suggestions,
      score: identical(score, _unset) ? this.score : score as int?,
      imageUrl: identical(imageUrl, _unset)
          ? this.imageUrl
          : imageUrl as String?,
      highlights: highlights ?? this.highlights,
      missingSkills: missingSkills ?? this.missingSkills,
      lowMatch: lowMatch ?? this.lowMatch,
      recommendations: recommendations ?? this.recommendations,
      sessionId: identical(sessionId, _unset)
          ? this.sessionId
          : sessionId as String?,
      cvId: identical(cvId, _unset) ? this.cvId : cvId as String?,
      isApplyingFixes: isApplyingFixes ?? this.isApplyingFixes,
      updatedPdfUrl: identical(updatedPdfUrl, _unset)
          ? this.updatedPdfUrl
          : updatedPdfUrl as String?,
    );
  }
}
