import 'package:flutter/foundation.dart';

/// Request Manager to prevent duplicate API calls
/// This is a singleton that tracks pending requests and prevents duplicate calls
class RequestManager {
  static final RequestManager _instance = RequestManager._internal();
  factory RequestManager() => _instance;
  RequestManager._internal();

  final Map<String, Future<dynamic>> _pendingRequests = {};

  /// Deduplicate requests by key - if a request with the same key is already in progress,
  /// return the existing future instead of making a new request
  Future<T> deduplicate<T>(String key, Future<T> Function() request) async {
    if (_pendingRequests.containsKey(key)) {
      debugPrint('🔄 Request deduplication: reusing existing request for $key');
      return await _pendingRequests[key] as T;
    }

    debugPrint('🚀 Starting new request for $key');
    final future = request();
    _pendingRequests[key] = future;
    
    try {
      final result = await future;
      debugPrint('✅ Request completed for $key');
      return result;
    } catch (e) {
      debugPrint('❌ Request failed for $key: $e');
      rethrow;
    } finally {
      _pendingRequests.remove(key);
    }
  }

  /// Clear all pending requests (useful for cleanup)
  void clear() {
    _pendingRequests.clear();
    debugPrint('🧹 Cleared all pending requests');
  }

  /// Get current pending request count
  int get pendingCount => _pendingRequests.length;

  /// Get all pending request keys (for debugging)
  List<String> get pendingKeys => _pendingRequests.keys.toList();

  /// Check if a specific request is pending
  bool isPending(String key) {
    return _pendingRequests.containsKey(key);
  }

  /// Get performance statistics
  Map<String, dynamic> getStats() {
    return {
      'pendingCount': pendingCount,
      'pendingKeys': pendingKeys,
      'totalSlotsUsed': _pendingRequests.length,
    };
  }
} 