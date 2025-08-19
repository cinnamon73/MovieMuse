import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/performance_service.dart';

class PerformanceMonitor extends StatefulWidget {
  final Widget child;
  final bool showOverlay;

  const PerformanceMonitor({
    required this.child,
    this.showOverlay = kDebugMode,
    super.key,
  });

  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor>
    with TickerProviderStateMixin {
  final PerformanceService _performanceService = PerformanceService();
  late AnimationController _fadeController;
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Start performance tracking
    if (widget.showOverlay) {
      _performanceService.trackFramePerformance();
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.showOverlay) _buildPerformanceOverlay(),
      ],
    );
  }

  Widget _buildPerformanceOverlay() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      right: 10,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _showDetails = !_showDetails;
          });
          if (_showDetails) {
            _fadeController.forward();
          } else {
            _fadeController.reverse();
          }
        },
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _getPerformanceColor(), width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPerformanceIndicator(),
              if (_showDetails) ...[
                const SizedBox(height: 8),
                FadeTransition(
                  opacity: _fadeController,
                  child: _buildDetailedStats(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPerformanceIndicator() {
    final score = _performanceService.getPerformanceScore();
    final isPerformingWell = _performanceService.isPerformingWell();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isPerformingWell ? Icons.check_circle : Icons.warning,
          color: _getPerformanceColor(),
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          '$score',
          style: TextStyle(
            color: _getPerformanceColor(),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailedStats() {
    final stats = _performanceService.getPerformanceStats();

    return Container(
      constraints: const BoxConstraints(maxWidth: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Performance Stats',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          ...stats.entries.map(
            (entry) => _buildStatRow(entry.key, entry.value),
          ),
          const SizedBox(height: 4),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildStatRow(String key, Map<String, dynamic> stats) {
    final average = stats['average']?.toStringAsFixed(1) ?? 'N/A';
    final count = stats['count']?.toString() ?? '0';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              _formatStatName(key),
              style: const TextStyle(color: Colors.white70, fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${average}ms ($count)',
            style: TextStyle(
              color: _getStatColor(key, stats['average']),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          icon: Icons.clear,
          onTap: () {
            _performanceService.clearLogs();
            setState(() {});
          },
          tooltip: 'Clear logs',
        ),
        _buildActionButton(
          icon: Icons.file_download,
          onTap: () => _exportPerformanceData(),
          tooltip: 'Export data',
        ),
        _buildActionButton(
          icon: Icons.memory,
          onTap: () => _showMemoryStats(),
          tooltip: 'Memory stats',
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, color: Colors.white70, size: 12),
        ),
      ),
    );
  }

  Color _getPerformanceColor() {
    final score = _performanceService.getPerformanceScore();
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  Color _getStatColor(String key, double? average) {
    if (average == null) return Colors.white70;

    switch (key) {
      case 'frame_render':
        return average > 16 ? Colors.red : Colors.green;
      case 'api_response':
      case 'movie_search':
        return average > 2000
            ? Colors.red
            : (average > 1000 ? Colors.orange : Colors.green);
      case 'image_load':
        return average > 1000
            ? Colors.red
            : (average > 500 ? Colors.orange : Colors.green);
      default:
        return Colors.white70;
    }
  }

  String _formatStatName(String key) {
    switch (key) {
      case 'frame_render':
        return 'Frame';
      case 'api_response':
        return 'API';
      case 'movie_search':
        return 'Search';
      case 'image_load':
        return 'Image';
      case 'preload_movies':
        return 'Preload';
      case 'recommendation_generation':
        return 'Recommend';
      default:
        return key.replaceAll('_', ' ');
    }
  }

  void _exportPerformanceData() {
    final data = _performanceService.exportPerformanceData();
    debugPrint('Performance Data Export: $data');

    // In a real app, you could save this to a file or send to analytics
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Performance data exported to debug console'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showMemoryStats() async {
    final memoryStats = await _performanceService.getMemoryStats();

    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Memory Statistics'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...memoryStats.entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text('${entry.key}: ${entry.value}'),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }
}

// Performance-aware ListView builder
class PerformanceListView extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final ScrollController? controller;
  final EdgeInsetsGeometry? padding;

  const PerformanceListView({
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.padding,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: padding,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // Wrap each item with performance monitoring
        return _PerformanceListItem(
          index: index,
          child: itemBuilder(context, index),
        );
      },
      // Performance optimizations
      cacheExtent: 250.0, // Cache items slightly off-screen
      addAutomaticKeepAlives: false, // Don't keep items alive unnecessarily
      addRepaintBoundaries: true, // Isolate repaints
      addSemanticIndexes: true, // Help with accessibility
    );
  }
}

class _PerformanceListItem extends StatelessWidget {
  final int index;
  final Widget child;

  const _PerformanceListItem({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: child);
  }
}
