import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'lib/services/server_streaming_service.dart';

void main() async {
  // Load environment variables
  await dotenv.load(fileName: '.env');
  
  runApp(ServerConnectionTestApp());
}

class ServerConnectionTestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Server Connection Test',
      home: ServerConnectionTestScreen(),
    );
  }
}

class ServerConnectionTestScreen extends StatefulWidget {
  @override
  _ServerConnectionTestScreenState createState() => _ServerConnectionTestScreenState();
}

class _ServerConnectionTestScreenState extends State<ServerConnectionTestScreen> {
  final ServerStreamingService _serverStreamingService = ServerStreamingService();
  
  List<String> _testResults = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  Future<void> _runTests() async {
    setState(() {
      _isLoading = true;
      _testResults.clear();
    });

    try {
      await _testServerHealth();
      await _testStreamingFilter();
      
      _addResult('✅ All tests completed!');
    } catch (e) {
      _addResult('❌ Test failed: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testServerHealth() async {
    _addResult('🌐 Testing server health...');
    
    try {
      final isHealthy = await _serverStreamingService.checkServerHealth();
      if (isHealthy) {
        _addResult('✅ Server is healthy');
      } else {
        _addResult('❌ Server health check failed');
      }
    } catch (e) {
      _addResult('❌ Server health test error: $e');
    }
  }

  Future<void> _testStreamingFilter() async {
    _addResult('🎬 Testing Netflix streaming filter...');
    
    try {
      final movies = await _serverStreamingService.filterMoviesByStreamingPlatforms(
        platforms: ['netflix'],
        region: 'US',
        type: 'movie',
        targetCount: 10,
      );
      
      _addResult('✅ Netflix filter returned ${movies.length} movies');
      
      if (movies.isNotEmpty) {
        _addResult('   Sample movies:');
        movies.take(3).forEach((movie) {
          _addResult('     - ${movie.title} (Rating: ${movie.voteAverage})');
        });
      } else {
        _addResult('   ⚠️ No movies returned - check server connection');
      }
      
    } catch (e) {
      _addResult('❌ Streaming filter test error: $e');
    }
  }

  void _addResult(String result) {
    setState(() {
      _testResults.add('${DateTime.now().toString().substring(11, 19)} $result');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Server Connection Test'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _runTests,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isLoading)
            LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(16),
              itemCount: _testResults.length,
              itemBuilder: (context, index) {
                final result = _testResults[index];
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    result,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: result.contains('❌') 
                          ? Colors.red 
                          : result.contains('✅') 
                              ? Colors.green 
                              : Colors.black,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
} 