import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, kReleaseMode;
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class TrailerPlayerSheet extends StatefulWidget {
  final String youtubeUrl;
  const TrailerPlayerSheet({super.key, required this.youtubeUrl});

  @override
  State<TrailerPlayerSheet> createState() => _TrailerPlayerSheetState();
}

class _TrailerPlayerSheetState extends State<TrailerPlayerSheet> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    // Only initialize the WebView/YouTube controller on mobile platforms
    if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      final videoId = YoutubePlayerController.convertUrlToId(widget.youtubeUrl);
      final controller = YoutubePlayerController(
              params: const YoutubePlayerParams(
        showFullscreenButton: false, // Disable built-in fullscreen button
        strictRelatedVideos: true,
        playsInline: true,
        enableCaption: false,
        showControls: true,
        mute: false,
      ),
      );
      _controller = controller;
      if (videoId != null) {
        controller.loadVideoById(videoId: videoId);
        controller.playVideo();
      }
    } else {
      // Desktop: In non-release builds, open externally to validate flow during testing
      if (!kReleaseMode) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          final uri = Uri.parse(widget.youtubeUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text('Trailer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                // Single explicit fullscreen button (built-in disabled)
                IconButton(
                  icon: const Icon(Icons.fullscreen),
                  onPressed: _controller == null ? null : () async {
                    final url = widget.youtubeUrl;
                    if (url.isEmpty) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => _FullscreenTrailerPage(youtubeUrl: url),
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
            if (_controller != null)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: AbsorbPointer(
                  absorbing: true, // block iframe taps to avoid pause/seek on accidental touches
                  child: YoutubePlayer(controller: _controller!),
                ),
              )
            else
              Container(
                height: MediaQuery.of(context).size.width * 9 / 16,
                alignment: Alignment.center,
                child: Text(
                  kReleaseMode
                      ? 'Trailer playback is available on mobile devices.'
                      : 'Opening trailer in your browser for testing (desktop dev only).',
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenTrailerPage extends StatefulWidget {
  final String youtubeUrl;
  const _FullscreenTrailerPage({required this.youtubeUrl});

  @override
  State<_FullscreenTrailerPage> createState() => _FullscreenTrailerPageState();
}

class _FullscreenTrailerPageState extends State<_FullscreenTrailerPage> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    // Force landscape and immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.leanBack);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    final videoId = YoutubePlayerController.convertUrlToId(widget.youtubeUrl);
    final controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showFullscreenButton: false, // Disable built-in fullscreen button
        strictRelatedVideos: true,
        playsInline: true,
        enableCaption: false,
        showControls: true,
        mute: false,
      ),
    );
    _controller = controller;
    if (videoId != null) {
      controller.loadVideoById(videoId: videoId);
      controller.playVideo();
    }
  }

  @override
  void dispose() {
    _controller?.close();
    // Restore portrait and UI
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: _controller == null
                  ? const SizedBox.shrink()
                  : AspectRatio(
                      aspectRatio: 16 / 9,
                      child: AbsorbPointer(
                        absorbing: true,
                        child: YoutubePlayer(controller: _controller!),
                      ),
                    ),
            ),
            // Back button
            Positioned(
              top: 16,
              left: 16,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


