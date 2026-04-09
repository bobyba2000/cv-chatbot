import 'package:flutter/material.dart';

class ChatbotTopPanel extends StatelessWidget {
  const ChatbotTopPanel({
    super.key,
    required this.cvFileName,
    required this.hasCv,
    required this.highlightJdSection,
    required this.isLoadingJds,
    required this.jdItems,
    required this.selectedJdId,
    required this.onRemoveJd,
    required this.onUploadCv,
    required this.onSearchChanged,
    required this.onSelectJd,
    required this.onViewJdDetail,
    required this.onEnterJdManually,
  });
  final String? cvFileName;
  final bool hasCv;
  final bool highlightJdSection;
  final bool isLoadingJds;
  final List<Map<String, dynamic>> jdItems;
  final String? selectedJdId;
  final VoidCallback onRemoveJd;
  final VoidCallback onUploadCv;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Map<String, dynamic>> onSelectJd;
  final ValueChanged<Map<String, dynamic>> onViewJdDetail;
  final VoidCallback onEnterJdManually;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: highlightJdSection
              ? Colors.amber.withValues(alpha: 0.12)
              : Colors.transparent,
          border: Border.all(
            color: highlightJdSection
                ? const Color(0xFFFFA000)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 280,
              child: TextField(
                onChanged: onSearchChanged,
                decoration: const InputDecoration(
                  labelText: 'Search JD',
                  hintText: 'Type job title...',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 126,
              child: isLoadingJds
                  ? const Center(child: CircularProgressIndicator())
                  : jdItems.isEmpty
                  ? const Center(child: Text('No JD found'))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: jdItems.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final jd = jdItems[index];
                        final id = (jd['id'] ?? '').toString();
                        final title = (jd['position'] ?? '').toString();
                        final rawDesc = jd['job_description'];
                        final description = rawDesc is List
                            ? rawDesc
                                  .map((item) => item.toString().trim())
                                  .where((item) => item.isNotEmpty)
                                  .take(2)
                                  .join(' | ')
                            : rawDesc.toString();
                        final isSelected =
                            selectedJdId != null && id == selectedJdId;

                        return SizedBox(
                          width: 280,
                          child: Material(
                            color: isSelected
                                ? Colors.blue.withValues(alpha: 0.08)
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(
                                color: isSelected
                                    ? Colors.blue
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => onSelectJd(jd),
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title.isEmpty
                                                ? 'Untitled position'
                                                : title,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () => onViewJdDetail(jd),
                                          icon: const Icon(Icons.info_outline),
                                          tooltip: 'View detail',
                                          visualDensity: VisualDensity.compact,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Expanded(
                                      child: Text(
                                        description.isEmpty
                                            ? 'No description'
                                            : description,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (cvFileName != null) Chip(label: Text('CV: $cvFileName')),

                OutlinedButton.icon(
                  onPressed: onUploadCv,
                  icon: const Icon(Icons.upload_file),
                  label: Text(hasCv ? 'Upload Another CV' : 'Upload CV'),
                ),
                OutlinedButton.icon(
                  onPressed: onEnterJdManually,
                  icon: const Icon(Icons.description_outlined),
                  label: const Text('Enter JD Manually'),
                ),
                if (selectedJdId != null)
                  TextButton(
                    onPressed: onRemoveJd,
                    child: const Text('Clear JD Selection'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
