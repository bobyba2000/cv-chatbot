import 'package:flutter/material.dart';

class ChatbotTopPanel extends StatelessWidget {
  const ChatbotTopPanel({
    super.key,
    required this.cvFileName,
    required this.hasCv,
    required this.hasJobDescription,
    required this.onRemoveJd,
    required this.onUploadCv,
    required this.onUseAnotherJd,
  });
  final String? cvFileName;
  final bool hasCv;
  final bool hasJobDescription;
  final VoidCallback onRemoveJd;
  final VoidCallback onUploadCv;
  final VoidCallback onUseAnotherJd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (cvFileName != null) Chip(label: Text('CV: $cvFileName')),
          if (hasJobDescription)
            Chip(label: const Text('JD added'), onDeleted: onRemoveJd),
          OutlinedButton.icon(
            onPressed: onUploadCv,
            icon: const Icon(Icons.upload_file),
            label: Text(hasCv ? 'Upload Another CV' : 'Upload CV'),
          ),
          OutlinedButton.icon(
            onPressed: onUseAnotherJd,
            icon: const Icon(Icons.description_outlined),
            label: const Text('Use Another JD'),
          ),
        ],
      ),
    );
  }
}
