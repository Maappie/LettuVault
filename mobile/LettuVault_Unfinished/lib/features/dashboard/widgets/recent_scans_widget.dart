import 'package:flutter/material.dart';
import '../../../../src/models/ai_scan.dart';
import '../../../../src/repositories/ai_repository.dart';

class RecentProduceScansWidget extends StatefulWidget {
  const RecentProduceScansWidget({super.key});

  @override
  State<RecentProduceScansWidget> createState() => _RecentProduceScansWidgetState();
}

class _RecentProduceScansWidgetState extends State<RecentProduceScansWidget> {
  final AiRepository _repo = AiRepository();
  bool _isLoading = true;
  List<AiProduceScan> _scans = [];

  @override
  void initState() {
    super.initState();
    _fetchScans();
  }

  Future<void> _fetchScans() async {
    setState(() => _isLoading = true);
    final results = await _repo.getProduceScans(limit: 3);
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

    if (_scans.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Text('No produce scans yet.', style: TextStyle(color: Colors.grey)),
        ),
      );
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
                        child: scan.image != null && scan.image!.startsWith('http')
                            ? Image.network(scan.image!, fit: BoxFit.cover)
                            : Container(
                                color: Colors.grey.withValues(alpha: 0.2),
                                child: const Center(child: Icon(Icons.image_not_supported)),
                              ),
                      ),
                      Container(
                        color: Theme.of(context).cardColor,
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              scan.produceType,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Conf: ${(scan.confidenceScore * 100).toStringAsFixed(1)}%',
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
