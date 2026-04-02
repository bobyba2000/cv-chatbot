import 'package:chatbot_cv/core/dependencies/app.dart';
import 'package:chatbot_cv/models/chat/model.dart';
import 'package:chatbot_cv/presentation/chatbot/widgets/chat_message_bubble.dart';
import 'package:chatbot_cv/presentation/chatbot/widgets/chatbot_input_bar.dart';
import 'package:chatbot_cv/presentation/chatbot/widgets/chatbot_top_panel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/chatbot.dart';

class CvChatbotPage extends StatefulWidget {
  const CvChatbotPage({super.key});

  @override
  State<CvChatbotPage> createState() => _CvChatbotPageState();
}

class _CvChatbotPageState extends State<CvChatbotPage> {
  final ChatbotService _apiService = AppDependencies.injector
      .get<ChatbotService>();

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
      final response = await _apiService.analyzeCv(
        cvBytes: bytes,
        fileName: file.name,
        jd: _jobDescription ?? '',
      );

      if (!response.isSuccessful) {
        setState(() {
          _messages.add(
            const ChatMessage(role: ChatRole.bot, text: 'CV upload failed '),
          );
        });
        _scrollToBottom();
        return;
      }

      final decoded = response.data;
      if (decoded == null) {
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
      final response = await _apiService.chat(
        message: message,
        jd: _jobDescription,
        hasCv: _hasCv,
        sessionId: _sessionId,
      );

      if (!response.isSuccessful) {
        setState(() {
          _messages.add(
            ChatMessage(
              role: ChatRole.bot,
              text: 'Request failed ${response.toString()}',
            ),
          );
        });
        return;
      }

      final decoded = response.data;
      if (decoded == null) {
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
      final response = await _apiService.applyFixes(
        sessionId: message.sessionId!,
        cvId: message.cvId!,
        highlights: message.highlights,
      );

      if (!response.isSuccessful) {
        setState(() {
          _messages[messageIndex] = _messages[messageIndex].copyWith(
            isApplyingFixes: false,
          );
          _messages.add(
            ChatMessage(
              role: ChatRole.bot,
              text: 'Failed to apply AI fixes ${response.toString()}.',
            ),
          );
        });
        _scrollToBottom();
        return;
      }

      final decoded = response.data;
      if (decoded == null) {
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

      final updatedPdfUrl = (decoded['updated_pdf_url'] ?? '').toString();

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
                  ChatbotTopPanel(
                    cvFileName: _cvFileName,
                    hasCv: _hasCv,
                    hasJobDescription: _jobDescription != null,
                    onRemoveJd: () {
                      setState(() {
                        _jobDescription = null;
                      });
                    },
                    onUploadCv: _hasCv ? _handleTryAnotherCv : _uploadCv,
                    onUseAnotherJd: _handleTryAnotherJd,
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: _messages.length + (_isTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isTyping && index == _messages.length) {
                          return const ChatTypingIndicator();
                        }
                        return ChatMessageBubble(
                          message: _messages[index],
                          index: index,
                          onTryAnotherCv: _handleTryAnotherCv,
                          onTryAnotherJd: _handleTryAnotherJd,
                          onApplyAiFixes: _applyAiFixes,
                          onOpenImageViewer: _openImageViewer,
                          onOpenExternalUrl: _openExternalUrl,
                          onSuggestionTap: (suggestion) {
                            _inputController.text = suggestion;
                          },
                        );
                      },
                    ),
                  ),
                  if (_isUploadingCv)
                    const LinearProgressIndicator(minHeight: 2),
                  ChatbotInputBar(
                    hasCv: _hasCv,
                    isTyping: _isTyping,
                    isUploadingCv: _isUploadingCv,
                    inputController: _inputController,
                    inputFocus: _inputFocus,
                    inputHint: _inputHint,
                    onUploadCv: _uploadCv,
                    onSendMessage: _sendMessage,
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
