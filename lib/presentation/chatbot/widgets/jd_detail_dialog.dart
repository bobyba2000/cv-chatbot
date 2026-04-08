import 'package:flutter/material.dart';

class JdDetailDialog extends StatelessWidget {
  const JdDetailDialog({
    super.key,
    required this.jd,
    required this.fallbackTitle,
    required this.fallbackText,
  });

  final Map<String, dynamic> jd;
  final String fallbackTitle;
  final String fallbackText;

  List<String> _toStringList(Object? value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final title = fallbackTitle.trim().isEmpty ? 'JD Detail' : fallbackTitle;
    final descriptions = _toStringList(jd['job_description']);
    final education = _toStringList(jd['education']);
    final skill = jd['skill'] is Map<String, dynamic>
        ? jd['skill'] as Map<String, dynamic>
        : <String, dynamic>{};

    final professional = _toStringList(skill['professional']);
    final technical = _toStringList(skill['technical']);
    final technology = _toStringList(skill['technology']);

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 12, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      title: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: 'Close',
          ),
        ],
      ),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionCard(
                title: 'Job Description',
                icon: Icons.description_outlined,
                child: descriptions.isEmpty
                    ? SelectableText(
                        fallbackText,
                        style: const TextStyle(height: 1.45),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: descriptions
                            .map(
                              (line) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 7),
                                      child: Icon(Icons.circle, size: 6),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SelectableText(
                                        line,
                                        style: const TextStyle(height: 1.35),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Skills',
                icon: Icons.psychology_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkillGroup(label: 'Professional', items: professional),
                    const SizedBox(height: 10),
                    _SkillGroup(label: 'Technical', items: technical),
                    const SizedBox(height: 10),
                    _SkillGroup(label: 'Technology', items: technology),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: 'Education',
                icon: Icons.school_outlined,
                child: education.isEmpty
                    ? const Text('No education requirement specified.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: education
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: SelectableText('• $item'),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey.shade800),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _SkillGroup extends StatelessWidget {
  const _SkillGroup({required this.label, required this.items});

  final String label;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        if (items.isEmpty)
          const Text('No items')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map(
                  (item) => Chip(
                    label: Text(item),
                    visualDensity: VisualDensity.compact,
                  ),
                )
                .toList(),
          ),
      ],
    );
  }
}
