import 'package:chatbot_cv/models/chat/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.index,
    required this.showApplyFixAction,
    required this.showDownloadAction,
    required this.onTryAnotherCv,
    required this.onTryAnotherJd,
    required this.onApplyAiFixes,
    required this.onOpenImageViewer,
    required this.onOpenExternalUrl,
    required this.onSuggestionTap,
  });
  final ChatMessage message;
  final int index;
  final bool showApplyFixAction;
  final bool showDownloadAction;
  final VoidCallback onTryAnotherCv;
  final VoidCallback onTryAnotherJd;
  final void Function(int messageIndex) onApplyAiFixes;
  final void Function(String url) onOpenImageViewer;
  final void Function(String url) onOpenExternalUrl;
  final void Function(String suggestion) onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final bubbleColor = isUser ? Colors.black : Colors.white;
    final textColor = isUser ? Colors.white : Colors.black87;
    final bubbleBorder = isUser
        ? Border.all()
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
                      onPressed: onTryAnotherCv,
                      child: const Text('Try Another CV'),
                    ),
                    OutlinedButton(
                      onPressed: onTryAnotherJd,
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
                          onPressed: () => onSuggestionTap(suggestion),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (message.imageUrl != null) ...[
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => onOpenImageViewer(message.imageUrl!),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                  showApplyFixAction &&
                  message.updatedPdfUrl == null &&
                  message.sessionId != null &&
                  message.cvId != null &&
                  message.highlights.isNotEmpty) ...[
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: message.isApplyingFixes
                      ? null
                      : () => onApplyAiFixes(index),
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
                  showDownloadAction &&
                  message.updatedPdfUrl != null &&
                  !message.lowMatch) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => onOpenExternalUrl(message.updatedPdfUrl!),
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
}

class ChatTypingIndicator extends StatelessWidget {
  const ChatTypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Text('Assistant is typing...'),
      ),
    );
  }
}
