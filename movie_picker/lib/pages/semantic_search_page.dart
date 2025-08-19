import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/server_streaming_service.dart';

class SemanticSearchPage extends StatefulWidget {
  const SemanticSearchPage({Key? key}) : super(key: key);

  @override
  State<SemanticSearchPage> createState() => _SemanticSearchPageState();
}

class _SemanticSearchPageState extends State<SemanticSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final ServerStreamingService _service = ServerStreamingService();
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];

  Future<void> _runSearch() async {
    final desc = _controller.text.trim();
    if (desc.isEmpty) return;
    setState(() { _loading = true; _results = []; });
    try {
      final results = await _service.semanticSearch(description: desc, maxPages: 2);
      setState(() { _results = results; });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Semantic search error: $e');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semantic search failed')),
      );
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Semantic Search')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Describe the movie you want',
                hintText: 'e.g., movie about obsessed stalker in the 2000s',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 5,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _runSearch,
                child: _loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Search'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _results.isEmpty
                  ? const Center(child: Text('No results yet'))
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final m = _results[index];
                        final title = m['title'] as String? ?? 'Unknown';
                        final overview = m['overview'] as String? ?? '';
                        final sim = (m['similarity'] as num?)?.toDouble() ?? 0.0;
                        final vote = (m['vote_average'] as num?)?.toDouble() ?? 0.0;
                        return ListTile(
                          title: Text(title),
                          subtitle: Text(
                            '${(sim * 100).toStringAsFixed(1)}% match • ⭐ ${vote.toStringAsFixed(1)}\n$overview',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
} 