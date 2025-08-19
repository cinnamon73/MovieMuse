import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class PerformanceService {
  static final PerformanceService _instance = PerformanceService._internal();
  factory PerformanceService() => _instance;
  PerformanceService._internal();

  final Map<String, DateTime> _startTimes = {};
  final Map<String, List<int>> _metrics = {};
  final List<String> _performanceLogs = [];

  // Performance thresholds (in milliseconds)
  static const int frameTimeThreshold = 16; // 60 FPS
  static const int apiResponseThreshold = 2000; // 2 seconds
  static const int imageLoadThreshold = 1000; // 1 second
  static const int appStartupThreshold = 3000; // 3 seconds

  /// Start timing an operation
  void startTimer(String operation) {
    _startTimes[operation] = DateTime.now();
  }

  /// End timing an operation and record the duration
  int endTimer(String operation) {
    final startTime = _startTimes[operation];
    if (startTime == null) {
      debugPrint('Warning: Timer for $operation was not started');
      return 0;
    }

    final duration = DateTime.now().difference(startTime).inMilliseconds;
    _recordMetric(operation, duration);
    _startTimes.remove(operation);

    // Log performance issues
    _checkPerformanceThreshold(operation, duration);

    return duration;
  }

  /// Record a metric value
  void _recordMetric(String metric, int value) {
    _metrics.putIfAbsent(metric, () => []).add(value);

    // Keep only last 100 measurements to prevent memory issues
    if (_metrics[metric]!.length > 100) {
      _metrics[metric]!.removeAt(0);
    }
  }

  /// Check if a performance threshold was exceeded
  void _checkPerformanceThreshold(String operation, int duration) {
    int threshold = 0;

    switch (operation) {
      case 'frame_render':
        threshold = frameTimeThreshold;
        break;
      case 'api_response':
      case 'movie_search':
      case 'recommendation_generation':
        threshold = apiResponseThreshold;
        break;
      case 'image_load':
        threshold = imageLoadThreshold;
        break;
      case 'app_startup':
        threshold = appStartupThreshold;
        break;
      default:
        return; // No threshold defined
    }

    if (duration > threshold) {
      final warning =
          'Performance Warning: $operation took ${duration}ms (threshold: ${threshold}ms)';
      _performanceLogs.add('${DateTime.now()}: $warning');
      debugPrint(warning);
    }
  }

  /// Get average performance for an operation
  double getAveragePerformance(String operation) {
    final metrics = _metrics[operation];
    if (metrics == null || metrics.isEmpty) return 0.0;

    return metrics.reduce((a, b) => a + b) / metrics.length;
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    final stats = <String, dynamic>{};

    for (final entry in _metrics.entries) {
      final values = entry.value;
      if (values.isEmpty) continue;

      values.sort();
      stats[entry.key] = {
        'average': values.reduce((a, b) => a + b) / values.length,
        'min': values.first,
        'max': values.last,
        'median': values[values.length ~/ 2],
        'count': values.length,
        'p95': values[(values.length * 0.95).floor()],
      };
    }

    return stats;
  }

  /// Monitor memory usage
  Future<Map<String, dynamic>> getMemoryStats() async {
    if (kIsWeb) {
      return {'error': 'Memory monitoring not available on web'};
    }

    try {
      // Get system memory info
      final ProcessInfo info = await Process.run('free', ['-m'])
          .then((result) => ProcessInfo.parse(result.stdout))
          .catchError((_) => ProcessInfo.empty());

      return {
        'timestamp': DateTime.now().toIso8601String(),
        'system_memory_mb': info.totalMemory,
        'available_memory_mb': info.availableMemory,
        'used_memory_mb': info.usedMemory,
        'memory_usage_percent': info.usagePercent,
      };
    } catch (e) {
      return {'error': 'Failed to get memory stats: $e'};
    }
  }

  /// Track frame rendering performance
  void trackFramePerformance() {
    if (!kDebugMode) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      startTimer('frame_render');

      WidgetsBinding.instance.addPostFrameCallback((_) {
        endTimer('frame_render');

        // Schedule next frame tracking
        Future.delayed(
          const Duration(milliseconds: 100),
          trackFramePerformance,
        );
      });
    });
  }

  /// Monitor API response times
  Future<T> monitorApiCall<T>(
    String apiName,
    Future<T> Function() apiCall,
  ) async {
    startTimer('api_response');
    startTimer(apiName);

    try {
      final result = await apiCall();
      endTimer('api_response');
      endTimer(apiName);
      return result;
    } catch (e) {
      endTimer('api_response');
      endTimer(apiName);
      _performanceLogs.add('${DateTime.now()}: API Error in $apiName: $e');
      rethrow;
    }
  }

  /// Monitor image loading performance
  Future<void> monitorImageLoad(
    String imageUrl,
    Future<void> Function() loadFunction,
  ) async {
    startTimer('image_load');

    try {
      await loadFunction();
      final duration = endTimer('image_load');

      if (duration > imageLoadThreshold) {
        _performanceLogs.add(
          '${DateTime.now()}: Slow image load for $imageUrl: ${duration}ms',
        );
      }
    } catch (e) {
      endTimer('image_load');
      _performanceLogs.add(
        '${DateTime.now()}: Image load error for $imageUrl: $e',
      );
      rethrow;
    }
  }

  /// Get performance logs
  List<String> getPerformanceLogs() {
    return List.from(_performanceLogs);
  }

  /// Clear performance logs
  void clearLogs() {
    _performanceLogs.clear();
  }

  /// Export performance data for analysis
  Map<String, dynamic> exportPerformanceData() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'metrics': getPerformanceStats(),
      'logs': getPerformanceLogs(),
      'device_info': {
        'platform': Platform.operatingSystem,
        'version': Platform.operatingSystemVersion,
      },
    };
  }

  /// Check if app is performing well
  bool isPerformingWell() {
    final stats = getPerformanceStats();

    // Check critical performance metrics
    final frameAvg = stats['frame_render']?['average'] as double? ?? 0.0;
    final apiAvg = stats['api_response']?['average'] as double? ?? 0.0;
    final imageAvg = stats['image_load']?['average'] as double? ?? 0.0;

    return frameAvg < frameTimeThreshold &&
        apiAvg < apiResponseThreshold &&
        imageAvg < imageLoadThreshold;
  }

  /// Get performance health score (0-100)
  int getPerformanceScore() {
    final stats = getPerformanceStats();
    int score = 100;

    // Deduct points for poor performance
    final frameAvg = stats['frame_render']?['average'] as double? ?? 0.0;
    if (frameAvg > frameTimeThreshold) {
      score -=
          ((frameAvg - frameTimeThreshold) / frameTimeThreshold * 30).round();
    }

    final apiAvg = stats['api_response']?['average'] as double? ?? 0.0;
    if (apiAvg > apiResponseThreshold) {
      score -=
          ((apiAvg - apiResponseThreshold) / apiResponseThreshold * 25).round();
    }

    final imageAvg = stats['image_load']?['average'] as double? ?? 0.0;
    if (imageAvg > imageLoadThreshold) {
      score -=
          ((imageAvg - imageLoadThreshold) / imageLoadThreshold * 20).round();
    }

    return score.clamp(0, 100);
  }
}

/// Helper class for parsing memory information
class ProcessInfo {
  final int totalMemory;
  final int availableMemory;
  final int usedMemory;
  final double usagePercent;

  ProcessInfo({
    required this.totalMemory,
    required this.availableMemory,
    required this.usedMemory,
    required this.usagePercent,
  });

  factory ProcessInfo.parse(String output) {
    // Parse memory information from system output
    // This is a simplified implementation
    return ProcessInfo(
      totalMemory: 0,
      availableMemory: 0,
      usedMemory: 0,
      usagePercent: 0.0,
    );
  }

  factory ProcessInfo.empty() {
    return ProcessInfo(
      totalMemory: 0,
      availableMemory: 0,
      usedMemory: 0,
      usagePercent: 0.0,
    );
  }
}
