import 'package:flutter/material.dart';
import '../../../../src/models/ai_scan.dart';
import '../../../../src/repositories/ai_repository.dart';

class RecentConditionScansWidget extends StatefulWidget {
  const RecentConditionScansWidget({super.key});

  @override
  State<RecentConditionScansWidget> createState() => _RecentConditionScansWidgetState();
}

class _RecentConditionScansWidgetState extends State<RecentConditionScansWidget> {
  final AiRepository _repo = AiRepository();
  bool _isLoading = true;
  List<AiConditionScan> _scans = [];

  @override
  void initState() {
    super.initState();
    _fetchScans();
  }

  Future<void> _fetchScans() async {
    setState(() => _isLoading = true);
    final results = await _repo.getConditionScans(limit: 3);
    if (mounted) {
      setState(() {
        _scans = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton.icon(
              onPressed: _fetchScans,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh'),
            )
          ],
        ),
        if (_scans.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No condition scans yet.', style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          SizedBox(
            height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _scans.length,
            itemBuilder: (context, index) {
              final scan = _scans[index];
              return Card(
                margin: const EdgeInsets.only(right: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: () {
                          if (scan.image == null || scan.image!.isEmpty) {
                            return Container(
                              color: Colors.grey.withValues(alpha: 0.2),
                              child: const Center(child: Icon(Icons.image_not_supported)),
                            );
                          }
                          final imageUrl = scan.image!.startsWith('http') 
                              ? scan.image! 
                              : 'http://10.42.0.1:8000/captures/${scan.image}';
                          return Image.network(
                            imageUrl, 
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey.withValues(alpha: 0.1),
                                child: const Center(
                                  child: SizedBox(
                                    width: 24, height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey.withValues(alpha: 0.2),
                              child: const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                            ),
                          );
                        }(),
                      ),
                      Container(
                        color: Theme.of(context).cardColor,
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              scan.label,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Worms: ${scan.wormCount} | Conf: ${(scan.confidenceScore * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
