import 'package:flutter/material.dart';
import 'package:my_new_app/src/repositories/ai_repository.dart';

class ProduceScanButton extends StatefulWidget {
  const ProduceScanButton({super.key});

  @override
  State<ProduceScanButton> createState() => _ProduceScanButtonState();
}

class _ProduceScanButtonState extends State<ProduceScanButton> {
  final _aiRepo = AiRepository();
  bool _isLoading = false;

  Future<void> _triggerScan() async {
    setState(() => _isLoading = true);
    try {
      await _aiRepo.triggerProduceScan();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produce scan triggered successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to trigger scan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: FilledButton.icon(
        onPressed: _isLoading ? null : _triggerScan,
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: _isLoading 
            ? const SizedBox(
                width: 20, 
                height: 20, 
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.document_scanner),
        label: Text(
          _isLoading ? 'TRIGGERING SCAN...' : 'START PRODUCE SCAN',
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
      ),
    );
  }
}
