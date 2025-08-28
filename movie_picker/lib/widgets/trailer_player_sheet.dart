import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class TrailerPlayerSheet extends StatefulWidget {
  final String youtubeUrl;
  const TrailerPlayerSheet({super.key, required this.youtubeUrl});

  @override
  State<TrailerPlayerSheet> createState() => _TrailerPlayerSheetState();
}

class _TrailerPlayerSheetState extends State<TrailerPlayerSheet> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayerController.convertUrlToId(widget.youtubeUrl);
    _controller = YoutubePlayerController(
      params: const YoutubePlayerParams(
        showFullscreenButton: true,
        strictRelatedVideos: true,
        autoPlay: true,
        playsInline: true,
      ),
    );
    if (videoId != null) {
      _controller.loadVideoById(videoId: videoId);
    }
  }

  @override
  void dispose() {
    _controller.close();
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
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: YoutubePlayer(controller: _controller),
            ),
          ],
        ),
      ),
    );
  }
}


