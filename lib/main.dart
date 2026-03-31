import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const CvChatbotApp());
}

class CvChatbotApp extends StatelessWidget {
  const CvChatbotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CV Chatbot Assistant',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: const Color(0xFFB00020),
              brightness: Brightness.light,
            ).copyWith(
              primary: const Color(0xFFB00020),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF6F6F6),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFF6F6F6),
          labelStyle: const TextStyle(color: Colors.black87),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB00020),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFB00020),
            side: const BorderSide(color: Color(0xFFB00020)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: const Color(0xFFB00020)),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(foregroundColor: const Color(0xFFB00020)),
        ),
      ),
      home: const CvChatbotPage(),
    );
  }
}

enum ChatRole { user, bot }

class CvHighlight {
  final String text;
  final String problem;
  final String suggestion;

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

  Map<String, String> toJson() {
    return {'text': text, 'problem': problem, 'suggestion': suggestion};
  }
}

class MissingSkill {
  final String skill;
  final String reason;
  final String suggestion;

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
}

class ChatMessage {
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

class CvChatbotPage extends StatefulWidget {
  const CvChatbotPage({super.key});

  @override
  State<CvChatbotPage> createState() => _CvChatbotPageState();
}

class _CvChatbotPageState extends State<CvChatbotPage> {
  static const String _apiBase = kDebugMode
      ? 'http://localhost:4000/api/chatbot'
      : 'https://vco-saas-d4b4443d487b.herokuapp.com/api/chatbot';

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [
    const ChatMessage(
      role: ChatRole.bot,
      text:
          'Hi, I am your CV Chatbot Assistant.\n\n1. Upload your CV PDF once.\n2. Paste a Job Description by starting a message with **JD:**\n3. Ask follow-up questions for rewrites, gaps, and improvements.',
    ),
  ];

  bool _isTyping = false;
  bool _isUploadingCv = false;
  bool _hasCv = false;
  String? _cvFileName;
  String? _jobDescription;
  String? _sessionId;
  bool _isPromptingJd = false;
  String _inputHint = 'Ask follow-up questions or paste JD with "JD:"';
  final FocusNode _inputFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptForJobDescription();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<String> _parseRecommendations(Object? raw) {
    if (raw is List) {
      return raw
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return [];
  }

  Future<void> _handleTryAnotherCv() async {
    setState(() {
      _hasCv = false;
      _cvFileName = null;
    });
    await _uploadCv();
  }

  void _handleTryAnotherJd() {
    setState(() {
      _jobDescription = null;
      _inputHint = 'Paste another Job Description...';
      _inputController.clear();
    });
    _inputFocus.requestFocus();
  }

  List<String> _resolveRecommendations(Object? raw, bool lowMatch) {
    if (!lowMatch) {
      return <String>[];
    }

    final parsed = _parseRecommendations(raw);
    if (parsed.isNotEmpty) {
      return parsed;
    }

    return [
      'Improve CV based on suggestions',
      'Provide a different JD to compare',
    ];
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _promptForJobDescription() async {
    if (_isPromptingJd || (_jobDescription?.trim().isNotEmpty ?? false)) {
      return;
    }

    _isPromptingJd = true;
    final controller = TextEditingController(text: _jobDescription ?? '');

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Job Description'),
          content: SizedBox(
            width: 480,
            child: TextField(
              controller: controller,
              minLines: 6,
              maxLines: 12,
              decoration: const InputDecoration(
                hintText:
                    'Paste the job description to validate your CV against it.',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a job description.'),
                    ),
                  );
                  return;
                }
                setState(() {
                  _jobDescription = text;
                  _inputHint = 'Ask follow-up questions or paste JD with "JD:"';
                });
                Navigator.of(context).pop();
              },
              child: const Text('Save JD'),
            ),
          ],
        );
      },
    );

    _isPromptingJd = false;
  }

  Future<void> _openImageViewer(String imageUrl) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(20),
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 5,
                  child: Center(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Failed to load annotated image.'),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }

    final launched = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open download link.')),
      );
    }
  }

  Future<void> _uploadCv() async {
    if (_hasCv || _isUploadingCv || _isTyping) {
      return;
    }

    if (_jobDescription == null || _jobDescription!.trim().isEmpty) {
      await _promptForJobDescription();
      if (_jobDescription == null || _jobDescription!.trim().isEmpty) {
        return;
      }
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() {
        _messages.add(
          const ChatMessage(
            role: ChatRole.bot,
            text: 'Could not read this file. Please choose another PDF.',
          ),
        );
      });
      _scrollToBottom();
      return;
    }

    setState(() {
      _isUploadingCv = true;
      _messages.add(
        ChatMessage(role: ChatRole.user, text: 'Uploaded CV: ${file.name}'),
      );
    });
    _scrollToBottom();

    try {
      final request =
          http.MultipartRequest('POST', Uri.parse('$_apiBase/analyze'))
            ..fields['jd'] = _jobDescription ?? ''
            ..files.add(
              http.MultipartFile.fromBytes('cv', bytes, filename: file.name),
            );

      final response = await request.send();
      final body = await response.stream.bytesToString();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        setState(() {
          _messages.add(
            ChatMessage(
              role: ChatRole.bot,
              text: 'CV upload failed (${response.statusCode}).\n$body',
            ),
          );
        });
        _scrollToBottom();
        return;
      }

      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        setState(() {
          _messages.add(
            const ChatMessage(
              role: ChatRole.bot,
              text: 'Upload succeeded, but response format was unexpected.',
            ),
          );
        });
        _scrollToBottom();
        return;
      }

      final responseType = (decoded['type'] ?? 'analysis').toString();
      final score = responseType == 'analysis'
          ? ((decoded['score'] as num?) ?? 0).round().clamp(0, 100)
          : null;
      final lowMatch =
          decoded['low_match'] == true || (score != null && score < 50);
      final recommendations = _resolveRecommendations(
        decoded['recommendations'],
        lowMatch,
      );
      final summary = (decoded['summary'] ?? '').toString();
      final imageUrl = (decoded['image_url'] ?? '').toString();
      final sessionId = (decoded['sessionId'] ?? '').toString();
      final cvId = (decoded['cvId'] ?? '').toString();
      final highlights = (decoded['highlights'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(CvHighlight.fromJson)
          .where((item) => item.text.isNotEmpty && item.suggestion.isNotEmpty)
          .toList();
      final missingSkills = (decoded['missing_skills'] as List<dynamic>? ?? [])
          .map(MissingSkill.fromJson)
          .where((item) => item.skill.trim().isNotEmpty)
          .take(8)
          .toList();

      setState(() {
        _hasCv = true;
        _cvFileName = file.name;
        _sessionId = sessionId.isEmpty ? _sessionId : sessionId;
        _messages.add(
          ChatMessage(
            role: ChatRole.bot,
            text: 'CV received successfully.\n\n$summary',
            score: score,
            imageUrl: imageUrl.isEmpty ? null : imageUrl,
            sessionId: sessionId.isEmpty ? null : sessionId,
            cvId: cvId.isEmpty ? null : cvId,
            highlights: highlights,
            missingSkills: missingSkills,
            lowMatch: lowMatch,
            recommendations: recommendations,
          ),
        );
      });
      _scrollToBottom();
    } catch (error) {
      setState(() {
        _messages.add(
          ChatMessage(role: ChatRole.bot, text: 'Upload error: $error'),
        );
      });
      _scrollToBottom();
    } finally {
      setState(() {
        _isUploadingCv = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    final rawText = _inputController.text.trim();
    if (rawText.isEmpty || _isTyping || _isUploadingCv) {
      return;
    }

    String message = rawText;
    if (rawText.toLowerCase().startsWith('jd:')) {
      final jdText = rawText.substring(3).trim();
      if (jdText.isNotEmpty) {
        _jobDescription = jdText;
        message = 'Job description updated for this session.';
      }
    }

    _inputController.clear();
    setState(() {
      _messages.add(ChatMessage(role: ChatRole.user, text: rawText));
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('$_apiBase/chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'jd': _jobDescription,
          'has_cv': _hasCv,
          'sessionId': _sessionId,
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        setState(() {
          _messages.add(
            ChatMessage(
              role: ChatRole.bot,
              text: 'Request failed (${response.statusCode}). ${response.body}',
            ),
          );
        });
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        setState(() {
          _messages.add(
            const ChatMessage(
              role: ChatRole.bot,
              text: 'Unexpected response format.',
            ),
          );
        });
        return;
      }

      final reply = (decoded['reply'] ?? '').toString();
      final suggestions = (decoded['suggestions'] as List<dynamic>? ?? [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
      final responseType = (decoded['type'] ?? 'chat').toString();
      final sessionId = (decoded['sessionId'] ?? '').toString();

      if (responseType == 'cv_update') {
        final message = (decoded['message'] ?? 'Here is your updated CV')
            .toString();
        final updatedPdfUrl = (decoded['updated_pdf_url'] ?? '').toString();
        final previewImageUrl = (decoded['preview_image_url'] ?? '').toString();

        setState(() {
          if (sessionId.isNotEmpty) {
            _sessionId = sessionId;
          }
          _messages.add(
            ChatMessage(
              role: ChatRole.bot,
              text: message,
              imageUrl: previewImageUrl.isEmpty ? null : previewImageUrl,
              updatedPdfUrl: updatedPdfUrl.isEmpty ? null : updatedPdfUrl,
            ),
          );
        });
        return;
      }

      setState(() {
        if (sessionId.isNotEmpty) {
          _sessionId = sessionId;
        }
        _messages.add(
          ChatMessage(
            role: ChatRole.bot,
            text: reply.isEmpty ? 'No reply generated.' : reply,
            suggestions: suggestions,
            score: responseType == 'analysis'
                ? ((decoded['score'] as num?) ?? 0).round().clamp(0, 100)
                : null,
          ),
        );
      });
    } catch (error) {
      setState(() {
        _messages.add(
          ChatMessage(role: ChatRole.bot, text: 'Network error: $error'),
        );
      });
    } finally {
      setState(() {
        _isTyping = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _applyAiFixes(int messageIndex) async {
    if (messageIndex < 0 || messageIndex >= _messages.length) {
      return;
    }

    final message = _messages[messageIndex];
    if (message.isApplyingFixes ||
        message.updatedPdfUrl != null ||
        message.sessionId == null ||
        message.cvId == null ||
        message.highlights.isEmpty) {
      return;
    }

    setState(() {
      _messages[messageIndex] = message.copyWith(isApplyingFixes: true);
    });
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('$_apiBase/apply-fixes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'sessionId': message.sessionId,
          'cvId': message.cvId,
          'highlights': message.highlights
              .map((item) => item.toJson())
              .toList(),
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        setState(() {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            isApplyingFixes: false,
          );
          _messages.add(
            ChatMessage(
              role: ChatRole.bot,
              text:
                  'Failed to apply AI fixes (${response.statusCode}). ${response.body}',
            ),
          );
        });
        _scrollToBottom();
        return;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        setState(() {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            isApplyingFixes: false,
          );
          _messages.add(
            const ChatMessage(
              role: ChatRole.bot,
              text:
                  'Updated CV was generated, but the response format was unexpected.',
            ),
          );
        });
        _scrollToBottom();
        return;
      }

      final resultMessage = (decoded['message'] ?? 'Updated CV generated')
          .toString();
      final updatedPdfUrl = (decoded['updated_pdf_url'] ?? '').toString();
      final previewImageUrl = (decoded['preview_image_url'] ?? '').toString();
      final responseType = (decoded['type'] ?? 'analysis').toString();
      final score = responseType == 'analysis'
          ? ((decoded['score'] as num?) ?? 0).round().clamp(0, 100)
          : null;
      final lowMatch =
          decoded['low_match'] == true || (score != null && score < 50);
      final recommendations = _resolveRecommendations(
        decoded['recommendations'],
        lowMatch,
      );

      setState(() {
        _messages[messageIndex] = _messages[messageIndex].copyWith(
          isApplyingFixes: false,
          updatedPdfUrl: updatedPdfUrl.isEmpty ? null : updatedPdfUrl,
        );
        // _messages.add(
        //   ChatMessage(
        //     role: ChatRole.bot,
        //     text:
        //         '$resultMessage\n\nYour updated CV is ready to download from the analysis card above.',
        //     imageUrl: previewImageUrl.isEmpty ? null : previewImageUrl,
        //     score: score,
        //     lowMatch: lowMatch,
        //     recommendations: recommendations,
        //   ),
        // );
      });
    } catch (error) {
      setState(() {
        _messages[messageIndex] = _messages[messageIndex].copyWith(
          isApplyingFixes: false,
        );
        _messages.add(
          ChatMessage(role: ChatRole.bot, text: 'Network error: $error'),
        );
      });
    } finally {
      _scrollToBottom();
    }
  }

  Widget _buildMessageBubble(ChatMessage message, int index) {
    final isUser = message.role == ChatRole.user;
    final bubbleColor = isUser ? Colors.black : Colors.white;
    final textColor = isUser ? Colors.white : Colors.black87;
    final bubbleBorder = isUser
        ? Border.all(color: Colors.black)
        : Border.all(color: const Color(0xFFE5E7EB));

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(14),
            border: bubbleBorder,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isUser)
                Text(message.text, style: TextStyle(color: textColor))
              else
                MarkdownBody(
                  data: message.text,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(
                    Theme.of(context),
                  ).copyWith(p: Theme.of(context).textTheme.bodyMedium),
                ),
              if (message.score != null) ...[
                const SizedBox(height: 10),
                Text(
                  'CV Score: ${message.score}/100',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    minHeight: 8,
                    value: message.score! / 100,
                    backgroundColor: isUser ? Colors.white24 : Colors.black12,
                    color: const Color(0xFFB00020),
                  ),
                ),
              ],
              if (message.score != null && message.lowMatch) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFEF9A9A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⚠️'),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Low match: Your CV is not suitable for this job.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: _handleTryAnotherCv,
                      child: const Text('Try Another CV'),
                    ),
                    OutlinedButton(
                      onPressed: _handleTryAnotherJd,
                      child: const Text('Try Another JD'),
                    ),
                  ],
                ),
              ],
              if (message.suggestions.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: message.suggestions
                      .map(
                        (suggestion) => ActionChip(
                          label: Text(suggestion),
                          onPressed: () {
                            _inputController.text = suggestion;
                          },
                        ),
                      )
                      .toList(),
                ),
              ],
              if (message.imageUrl != null) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _openImageViewer(message.imageUrl!),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      message.imageUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: Text('Failed to load annotated image.'),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap image to zoom',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ],
              if (!isUser && message.missingSkills.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Missing Skills',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Column(
                  children: message.missingSkills.map((skill) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              skill.skill,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('Reason: ${skill.reason}'),
                            const SizedBox(height: 4),
                            Text('Suggestion: ${skill.suggestion}'),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (!isUser &&
                  message.updatedPdfUrl == null &&
                  message.sessionId != null &&
                  message.cvId != null &&
                  message.highlights.isNotEmpty) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: message.isApplyingFixes
                      ? null
                      : () => _applyAiFixes(index),
                  icon: message.isApplyingFixes
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_fix_high),
                  label: Text(
                    message.isApplyingFixes
                        ? 'Applying AI Fixes...'
                        : 'Apply AI Fixes',
                  ),
                ),
              ],
              if (!isUser &&
                  message.updatedPdfUrl != null &&
                  !message.lowMatch) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _openExternalUrl(message.updatedPdfUrl!),
                  icon: const Icon(Icons.download),
                  label: const Text('Download Updated CV'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text('Assistant is typing...'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CV Chatbot Assistant')),
      body: Container(
        color: Colors.white,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (_cvFileName != null)
                          Chip(label: Text('CV: $_cvFileName')),
                        if (_jobDescription != null)
                          Chip(
                            label: const Text('JD added'),
                            onDeleted: () {
                              setState(() {
                                _jobDescription = null;
                              });
                            },
                          ),
                        OutlinedButton.icon(
                          onPressed: _hasCv ? _handleTryAnotherCv : _uploadCv,
                          icon: const Icon(Icons.upload_file),
                          label: Text(
                            _hasCv ? 'Upload Another CV' : 'Upload CV',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _handleTryAnotherJd,
                          icon: const Icon(Icons.description_outlined),
                          label: const Text('Use Another JD'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length + (_isTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isTyping && index == _messages.length) {
                          return _buildTypingIndicator();
                        }
                        return _buildMessageBubble(_messages[index], index);
                      },
                    ),
                  ),
                  if (_isUploadingCv)
                    const LinearProgressIndicator(minHeight: 2),
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      border: const Border(
                        top: BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _hasCv ? null : _uploadCv,
                          icon: Icon(
                            _hasCv ? Icons.check_circle : Icons.upload_file,
                          ),
                          tooltip: _hasCv ? 'CV uploaded' : 'Upload CV',
                        ),
                        Expanded(
                          child: TextField(
                            controller: _inputController,
                            minLines: 1,
                            maxLines: 5,
                            textInputAction: TextInputAction.newline,
                            decoration: InputDecoration(
                              hintText: _inputHint,
                              isDense: true,
                            ),
                            focusNode: _inputFocus,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: (_isTyping || _isUploadingCv)
                              ? null
                              : _sendMessage,
                          icon: const Icon(Icons.send),
                          tooltip: 'Send',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
