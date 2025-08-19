import 'package:flutter/material.dart';

class TasteWarmupPage extends StatelessWidget {
	final int totalInteractions;
	const TasteWarmupPage({Key? key, required this.totalInteractions}) : super(key: key);

	@override
	Widget build(BuildContext context) {
		final remaining = (50 - totalInteractions).clamp(0, 50);
		final progress = (totalInteractions / 50).clamp(0.0, 1.0);
		return Scaffold(
			appBar: AppBar(title: const Text('Build Your Taste')),
			body: Padding(
				padding: const EdgeInsets.all(20),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						const Text(
							"Let's unlock For You",
							style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
						),
						const SizedBox(height: 12),
						Text(
							"Swipe on 50 movies to teach MovieMuse your taste. Then we'll generate high-precision recommendations just for you.",
							style: const TextStyle(fontSize: 16, color: Colors.white70),
						),
						const SizedBox(height: 24),
						LinearProgressIndicator(value: progress, minHeight: 10, backgroundColor: Colors.white12),
						const SizedBox(height: 8),
						Text("Progress: ${totalInteractions >= 50 ? 50 : totalInteractions}/50", style: const TextStyle(color: Colors.white70)),
						const SizedBox(height: 24),
						Container(
							padding: const EdgeInsets.all(16),
							decoration: BoxDecoration(
								color: Colors.white10,
								borderRadius: BorderRadius.circular(12),
								border: Border.all(color: Colors.white12),
							),
							child: Row(
								children: [
									const Icon(Icons.psychology, color: Colors.amber),
									const SizedBox(width: 12),
									Expanded(
										child: Text(
											remaining > 0
												? "You're ${remaining} swipes away from unlocking For You."
												: "You're ready! For You is unlocked.",
											style: const TextStyle(fontSize: 16),
										),
									),
							],
							),
						),
						const Spacer(),
						SizedBox(
							width: double.infinity,
							child: ElevatedButton.icon(
								onPressed: () => Navigator.pop(context),
								icon: const Icon(Icons.trending_up),
								label: const Text('Start Swiping on Trending'),
							),
						),
					],
				),
			),
		);
	}
} 