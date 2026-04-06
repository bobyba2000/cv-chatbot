import 'package:flutter/material.dart';

class ChatbotInputBar extends StatelessWidget {
  const ChatbotInputBar({
    super.key,
    required this.hasCv,
    required this.isTyping,
    required this.isUploadingCv,
    required this.isMessageLimitReached,
    required this.inputController,
    required this.inputFocus,
    required this.inputHint,
    required this.onUploadCv,
    required this.onSendMessage,
  });
  final bool hasCv;
  final bool isTyping;
  final bool isUploadingCv;
  final bool isMessageLimitReached;
  final TextEditingController inputController;
  final FocusNode inputFocus;
  final String inputHint;
  final VoidCallback onUploadCv;
  final VoidCallback onSendMessage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: const Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: hasCv ? null : onUploadCv,
            icon: Icon(hasCv ? Icons.check_circle : Icons.upload_file),
            tooltip: hasCv ? 'CV uploaded' : 'Upload CV',
          ),
          Expanded(
            child: TextField(
              controller: inputController,
              enabled: !isMessageLimitReached,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(hintText: inputHint, isDense: true),
              focusNode: inputFocus,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: (isTyping || isUploadingCv || isMessageLimitReached)
                ? null
                : onSendMessage,
            icon: const Icon(Icons.send),
            tooltip: 'Send',
          ),
        ],
      ),
    );
  }
}
