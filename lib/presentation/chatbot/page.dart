import 'package:chatbot_cv/core/dependencies/app.dart';
import 'package:chatbot_cv/models/chat/model.dart';
import 'package:chatbot_cv/presentation/chatbot/widgets/chat_message_bubble.dart';
import 'package:chatbot_cv/presentation/chatbot/widgets/chatbot_input_bar.dart';
import 'package:chatbot_cv/presentation/chatbot/widgets/jd_detail_dialog.dart';
import 'package:chatbot_cv/presentation/chatbot/widgets/chatbot_top_panel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/chatbot.dart';
import '../../services/jd.dart';

class CvChatbotPage extends StatefulWidget {
  const CvChatbotPage({super.key});

  @override
  State<CvChatbotPage> createState() => _CvChatbotPageState();
}

class _CvChatbotPageState extends State<CvChatbotPage> {
  static const int _maxUserMessages = 5;

  final ChatbotService _apiService = AppDependencies.injector
      .get<ChatbotService>();
  final JdService _jdService = AppDependencies.injector.get<JdService>();

  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _pageScrollController = ScrollController();
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
  String? _selectedJdId;
  String _jdSearchQuery = '';
  bool _isLoadingJds = false;
  List<Map<String, dynamic>> _jdLibrary = const [];
  String? _sessionId;
  bool _isPromptingJd = false;
  bool _highlightJdPanel = false;
  String _inputHint = 'Ask follow-up questions or paste JD with "JD:"';
  final FocusNode _inputFocus = FocusNode();
  int _sentMessageCount = 0;
  bool _hasShownChatLimitNotice = false;

  @override
  void initState() {
    super.initState();
    _loadJdLibrary();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    _pageScrollController.dispose();
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
      _sentMessageCount = 0;
      _hasShownChatLimitNotice = false;
    });
    await _uploadCv();
  }

  bool get _hasReachedMessageLimit => _sentMessageCount >= _maxUserMessages;

  bool _canApplyFix(ChatMessage message) {
    return message.updatedPdfUrl == null &&
        message.sessionId != null &&
        message.cvId != null &&
        message.highlights.isNotEmpty;
  }

  int? _latestActionableMessageIndex() {
    for (int index = _messages.length - 1; index >= 0; index -= 1) {
      final message = _messages[index];
      if (message.role != ChatRole.bot) {
        continue;
      }
      if (message.updatedPdfUrl != null || _canApplyFix(message)) {
        return index;
      }
    }
    return null;
  }

  int? _latestApplicableFixSourceIndex(int upToIndex) {
    if (_messages.isEmpty) {
      return null;
    }

    final safeEndIndex = upToIndex.clamp(0, _messages.length - 1);
    for (int index = safeEndIndex; index >= 0; index -= 1) {
      final message = _messages[index];
      if (message.role != ChatRole.bot) {
        continue;
      }
      if (_canApplyFix(message)) {
        return index;
      }
    }
    return null;
  }

  bool _shouldShowApplyFixAction(int messageIndex) {
    if (messageIndex <= 0 || messageIndex >= _messages.length) {
      return false;
    }
    final message = _messages[messageIndex];
    if (message.role != ChatRole.bot || message.updatedPdfUrl != null) {
      return false;
    }
    return _latestApplicableFixSourceIndex(messageIndex) != null;
  }

  List<Map<String, String>> _buildHistoryUntilMessage(int messageIndex) {
    if (_messages.isEmpty) {
      return const <Map<String, String>>[];
    }

    final safeEndIndex = messageIndex.clamp(0, _messages.length - 1);
    final history = <Map<String, String>>[];
    for (int index = 0; index <= safeEndIndex; index += 1) {
      final message = _messages[index];
      final content = message.text.trim();
      if (content.isEmpty) {
        continue;
      }
      history.add({
        'role': message.role == ChatRole.user ? 'user' : 'assistant',
        'content': content,
      });
    }
    return history;
  }

  void _appendChatLimitNoticeIfNeeded() {
    if (!_hasReachedMessageLimit || _hasShownChatLimitNotice) {
      return;
    }

    final latestIndex = _latestActionableMessageIndex();
    final source = latestIndex != null ? _messages[latestIndex] : null;

    _messages.add(
      ChatMessage(
        role: ChatRole.bot,
        text:
            'You have reached the 5-message limit for this chat. Use the latest CV action below to continue.',
        sessionId: source?.sessionId,
        cvId: source?.cvId,
        highlights: source?.highlights ?? const <CvHighlight>[],
        updatedPdfUrl: source?.updatedPdfUrl,
        showApplyFix:
            source?.showApplyFix ??
            _canApplyFix(
              source ?? const ChatMessage(role: ChatRole.bot, text: ''),
            ),
        isChatLimitNotice: true,
      ),
    );

    _hasShownChatLimitNotice = true;
    _inputHint =
        'Message limit reached. Download the latest CV or apply fixes below.';
  }

  Future<void> _handleTryAnotherJd() async {
    setState(() {
      _jobDescription = null;
      _selectedJdId = null;
      _jdSearchQuery = '';
      _inputHint = 'Paste another Job Description...';
      _inputController.clear();
      _highlightJdPanel = true;
    });

    if (_pageScrollController.hasClients) {
      await _pageScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _highlightJdPanel = false;
      });
    });
  }

  String _extractTitle(Map<String, dynamic> jd) {
    return (jd['position'] ?? '').toString().trim();
  }

  List<Map<String, dynamic>> get _orderedJds {
    final items = List<Map<String, dynamic>>.from(_jdLibrary);
    items.sort((a, b) {
      final aId = (a['id'] ?? '').toString();
      final bId = (b['id'] ?? '').toString();
      if (_selectedJdId != null && aId == _selectedJdId) {
        return -1;
      }
      if (_selectedJdId != null && bId == _selectedJdId) {
        return 1;
      }
      return _extractTitle(a).compareTo(_extractTitle(b));
    });
    return items;
  }

  List<Map<String, dynamic>> get _visibleJds {
    final query = _jdSearchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return _orderedJds;
    }
    return _orderedJds.where((jd) {
      final title = _extractTitle(jd).toLowerCase();
      final rawDesc = jd['job_description'];
      final description = rawDesc is List
          ? rawDesc.map((item) => item.toString()).join(' ').toLowerCase()
          : rawDesc.toString().toLowerCase();
      return title.contains(query) || description.contains(query);
    }).toList();
  }

  String _formatJdText(Map<String, dynamic> jd) {
    final position = _extractTitle(jd);
    final descriptions = (jd['job_description'] is List)
        ? (jd['job_description'] as List)
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList()
        : <String>[];
    final education = (jd['education'] is List)
        ? (jd['education'] as List)
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toList()
        : <String>[];
    final skill = jd['skill'] is Map<String, dynamic>
        ? jd['skill'] as Map<String, dynamic>
        : <String, dynamic>{};

    String formatSkillList(String key) {
      final value = skill[key];
      if (value is! List) {
        return '';
      }
      final items = value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
      if (items.isEmpty) {
        return '';
      }
      return '- $key: ${items.join(', ')}';
    }

    final skillLines = [
      formatSkillList('professional'),
      formatSkillList('technical'),
      formatSkillList('technology'),
    ].where((line) => line.isNotEmpty).toList();

    final buffer = StringBuffer();
    if (position.isNotEmpty) {
      buffer.writeln('Position: $position');
    }
    if (descriptions.isNotEmpty) {
      buffer.writeln('\nJob Description:');
      for (final line in descriptions) {
        buffer.writeln('- $line');
      }
    }
    if (skillLines.isNotEmpty) {
      buffer.writeln('\nSkill:');
      for (final line in skillLines) {
        buffer.writeln(line);
      }
    }
    if (education.isNotEmpty) {
      buffer.writeln('\nEducation:');
      for (final line in education) {
        buffer.writeln('- $line');
      }
    }
    return buffer.toString().trim();
  }

  Future<void> _loadJdLibrary() async {
    setState(() {
      _isLoadingJds = true;
    });

    final response = await _jdService.getJds();
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingJds = false;
      if (response.isSuccessful) {
        _jdLibrary = response.data ?? const [];
      }
    });
  }

  void _selectJd(Map<String, dynamic> jd) {
    final id = (jd['id'] ?? '').toString();
    if (id.isEmpty) {
      return;
    }
    final jdName = _extractTitle(jd);

    setState(() {
      _selectedJdId = id;
      _jobDescription = _formatJdText(jd);
      _inputHint = 'Ask follow-up questions or paste JD with "JD:"';
      _messages.add(
        ChatMessage(
          role: ChatRole.bot,
          text: 'Job description selected.',
          selectedJdName: jdName.isEmpty ? 'Untitled position' : jdName,
        ),
      );
    });
    _scrollToBottom();
  }

  Future<void> _showJdDetail(Map<String, dynamic> jd) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return JdDetailDialog(
          jd: jd,
          fallbackTitle: _extractTitle(jd),
          fallbackText: _formatJdText(jd),
        );
      },
    );
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
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
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
                  _selectedJdId = null;
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
        _sentMessageCount = 0;
        _hasShownChatLimitNotice = false;
        _inputHint = 'Ask follow-up questions or paste JD with "JD:"';
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
    if (rawText.isEmpty ||
        _isTyping ||
        _isUploadingCv ||
        _hasReachedMessageLimit) {
      if (_hasReachedMessageLimit && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You have reached the 5-message limit. Use the latest CV action below.',
            ),
          ),
        );
      }
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
      _sentMessageCount += 1;
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
        final latestActionIndex = _latestActionableMessageIndex();
        final latestActionMessage = latestActionIndex != null
            ? _messages[latestActionIndex]
            : null;
        final showApplyFix = decoded['show_apply_fix'] == true;
        final inheritedSessionId = latestActionMessage?.sessionId;
        final inheritedCvId = latestActionMessage?.cvId;
        final inheritedHighlights =
            latestActionMessage?.highlights ?? const <CvHighlight>[];
        final canInheritApplyFix =
            inheritedSessionId != null &&
            inheritedCvId != null &&
            inheritedHighlights.isNotEmpty &&
            latestActionMessage?.updatedPdfUrl == null;
        _messages.add(
          ChatMessage(
            role: ChatRole.bot,
            text: reply.isEmpty ? 'No reply generated.' : reply,
            suggestions: suggestions,
            score: responseType == 'analysis'
                ? ((decoded['score'] as num?) ?? 0).round().clamp(0, 100)
                : null,
            sessionId: showApplyFix
                ? (latestActionMessage?.sessionId ??
                      (sessionId.isEmpty ? null : sessionId))
                : (canInheritApplyFix ? inheritedSessionId : null),
            cvId: showApplyFix
                ? latestActionMessage?.cvId
                : (canInheritApplyFix ? inheritedCvId : null),
            highlights: showApplyFix
                ? (latestActionMessage?.highlights ?? const <CvHighlight>[])
                : (canInheritApplyFix
                      ? inheritedHighlights
                      : const <CvHighlight>[]),
            showApplyFix: showApplyFix || canInheritApplyFix,
          ),
        );
        _appendChatLimitNoticeIfNeeded();
      });
    } catch (error) {
      setState(() {
        _messages.add(
          ChatMessage(role: ChatRole.bot, text: 'Network error: $error'),
        );
        _appendChatLimitNoticeIfNeeded();
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

    final tappedMessage = _messages[messageIndex];
    if (tappedMessage.isApplyingFixes || tappedMessage.updatedPdfUrl != null) {
      return;
    }

    final sourceIndex = _latestApplicableFixSourceIndex(messageIndex);
    if (sourceIndex == null) {
      return;
    }

    final sourceMessage = _messages[sourceIndex];
    if (sourceMessage.sessionId == null ||
        sourceMessage.cvId == null ||
        sourceMessage.highlights.isEmpty) {
      return;
    }

    setState(() {
      _messages[messageIndex] = tappedMessage.copyWith(isApplyingFixes: true);
    });
    _scrollToBottom();

    try {
      final response = await _apiService.applyFixes(
        sessionId: sourceMessage.sessionId!,
        cvId: sourceMessage.cvId!,
        highlights: sourceMessage.highlights,
        history: _buildHistoryUntilMessage(messageIndex),
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
      final previewImageUrl = (decoded['preview_image_url'] ?? '').toString();

      setState(() {
        _messages[messageIndex] = _messages[messageIndex].copyWith(
          isApplyingFixes: false,
          updatedPdfUrl: updatedPdfUrl.isEmpty ? null : updatedPdfUrl,
          imageUrl: previewImageUrl.isEmpty ? null : previewImageUrl,
          showApplyFix: false,
        );
        if (_hasReachedMessageLimit) {
          final existingNoticeIndex = _messages.indexWhere(
            (item) => item.isChatLimitNotice,
          );
          if (existingNoticeIndex >= 0) {
            _messages[existingNoticeIndex] = _messages[existingNoticeIndex]
                .copyWith(
                  updatedPdfUrl: updatedPdfUrl.isEmpty ? null : updatedPdfUrl,
                  showApplyFix: false,
                );
          }
        }
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
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _pageScrollController,
                      child: Column(
                        children: [
                          ChatbotTopPanel(
                            cvFileName: _cvFileName,
                            hasCv: _hasCv,
                            highlightJdSection: _highlightJdPanel,
                            isLoadingJds: _isLoadingJds,
                            jdItems: _visibleJds,
                            selectedJdId: _selectedJdId,
                            onRemoveJd: () {
                              setState(() {
                                _jobDescription = null;
                                _selectedJdId = null;
                              });
                            },
                            onUploadCv: _hasCv
                                ? _handleTryAnotherCv
                                : _uploadCv,
                            onSearchChanged: (value) {
                              setState(() {
                                _jdSearchQuery = value;
                              });
                            },
                            onSelectJd: _selectJd,
                            onViewJdDetail: _showJdDetail,
                            onEnterJdManually: _promptForJobDescription,
                          ),
                          ListView.builder(
                            controller: _scrollController,
                            shrinkWrap: true,
                            padding: const EdgeInsets.all(12),
                            itemCount: _messages.length + (_isTyping ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (_isTyping && index == _messages.length) {
                                return const ChatTypingIndicator();
                              }
                              return ChatMessageBubble(
                                message: _messages[index],
                                index: index,
                                showApplyFixAction: _shouldShowApplyFixAction(
                                  index,
                                ),
                                showDownloadAction:
                                    _messages[index].updatedPdfUrl != null,
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
                        ],
                      ),
                    ),
                  ),
                  if (_isUploadingCv)
                    const LinearProgressIndicator(minHeight: 2),
                  ChatbotInputBar(
                    hasCv: _hasCv,
                    isTyping: _isTyping,
                    isUploadingCv: _isUploadingCv,
                    isMessageLimitReached: _hasReachedMessageLimit,
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
