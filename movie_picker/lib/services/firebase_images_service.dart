import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class FirebaseImagesService {
	final FirebaseFirestore _firestore = FirebaseFirestore.instance;
	final Dio _dio = Dio();

	// Simple in-memory cache per movie
	final Map<int, List<Map<String, dynamic>>> _backdropCache = {};
	final Map<int, DateTime> _cacheTs = {};
	static const Duration _cacheTtl = Duration(hours: 24);

	bool _isValid(int movieId) {
		final ts = _cacheTs[movieId];
		if (ts == null) return false;
		return DateTime.now().difference(ts) < _cacheTtl;
	}

	Future<List<Map<String, dynamic>>> getBackdropsForMovie(int movieId) async {
		if (_isValid(movieId)) {
			final cached = _backdropCache[movieId];
			if (cached != null) return cached;
		}

		try {
			final doc = await _firestore.collection('movieImages').doc(movieId.toString()).get();
			if (!doc.exists) {
				debugPrint('ℹ️ No image metadata in Firestore for movie $movieId');
				return [];
			}
			final data = doc.data();
			if (data == null) return [];

			final List<dynamic> backdrops = (data['backdrops'] as List?) ?? [];
			final List<Map<String, dynamic>> normalized = backdrops
					.whereType<Map<String, dynamic>>()
					.map((b) {
						final filePath = b['file_path'] as String?;
						if (filePath == null || filePath.isEmpty) return null;
						return {
							'file_path': filePath,
							'width': b['width'],
							'height': b['height'],
							'vote_average': (b['vote_average'] as num?)?.toDouble() ?? 0.0,
							'iso_639_1': b['iso_639_1'],
							'url_w780': 'https://image.tmdb.org/t/p/w780$filePath',
							'url_original': 'https://image.tmdb.org/t/p/original$filePath',
						};
					})
					.whereType<Map<String, dynamic>>()
					.toList();

			_backdropCache[movieId] = normalized;
			_cacheTs[movieId] = DateTime.now();
			return normalized;
		} catch (e) {
			debugPrint('❌ Error loading backdrops for $movieId: $e');
			return [];
		}
	}

	// Ensure images exist in Firestore; if not, call Cloud Function then re-read. If still empty, fallback to TMDB directly.
	Future<List<Map<String, dynamic>>> ensureBackdropsForMovie({
		required int movieId,
		required String firebaseProjectId,
	}) async {
		final existing = await getBackdropsForMovie(movieId);
		if (existing.isNotEmpty) return existing;

		bool wrote = false;
		try {
			// Call the CF via region default (us-central1)
			final url = 'https://us-central1-$firebaseProjectId.cloudfunctions.net/fetchMovieImages';
			await _dio.post(url, data: { 'movieId': movieId });
			wrote = true;
		} catch (e) {
			debugPrint('❌ Failed to trigger fetchMovieImages for $movieId: $e');
		}

		// Re-read after CF
		if (wrote) {
			await Future.delayed(const Duration(milliseconds: 250));
			final afterCf = await getBackdropsForMovie(movieId);
			if (afterCf.isNotEmpty) return afterCf;
		}

		// Fallback: Fetch from TMDB directly if key available
		final tmdbKey = dotenv.env['TMDB_API_KEY'] ?? '';
		if (tmdbKey.isEmpty) {
			return [];
		}
		try {
			final resp = await _dio.get('https://api.themoviedb.org/3/movie/$movieId/images', queryParameters: {
				'api_key': tmdbKey,
				'include_image_language': 'null,en',
				'language': 'en',
			});
			final List<dynamic> backdrops = (resp.data['backdrops'] as List?) ?? [];
			final List<Map<String, dynamic>> normalized = backdrops
					.whereType<Map<String, dynamic>>()
					.where((b) => (b['file_path'] as String?)?.isNotEmpty == true)
					.toList()
				..sort((a, b) => ((b['vote_average'] ?? 0) as num).compareTo((a['vote_average'] ?? 0) as num));
			final sliced = normalized.take(8).map((b) {
				final filePath = b['file_path'] as String;
				return {
					'file_path': filePath,
					'width': b['width'],
					'height': b['height'],
					'vote_average': (b['vote_average'] as num?)?.toDouble() ?? 0.0,
					'iso_639_1': b['iso_639_1'],
					'url_w780': 'https://image.tmdb.org/t/p/w780$filePath',
					'url_original': 'https://image.tmdb.org/t/p/original$filePath',
				};
			}).toList();

			// Try writing to Firestore for caching (ignore errors)
			try {
				await _firestore.collection('movieImages').doc(movieId.toString()).set({
					'backdrops': sliced.map((m) => {
						'file_path': m['file_path'],
						'width': m['width'],
						'height': m['height'],
						'vote_average': m['vote_average'],
						'iso_639_1': m['iso_639_1'],
					}).toList(),
					'updatedAt': FieldValue.serverTimestamp(),
				}, SetOptions(merge: true));
			} catch (_) {}

			_backdropCache[movieId] = sliced;
			_cacheTs[movieId] = DateTime.now();
			return sliced;
		} catch (e) {
			debugPrint('❌ TMDB fallback failed for $movieId: $e');
			return [];
		}
	}
} 