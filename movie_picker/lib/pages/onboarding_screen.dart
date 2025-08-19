import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final AuthService authService;

  const OnboardingScreen({super.key, required this.onComplete, required this.authService});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingPage> _pages = [
    OnboardingPage(
      title: 'Welcome to MovieMuse!',
      description:
          'Discover your next favorite movie with our intuitive swiping interface. Get personalized recommendations and find where to watch instantly.',
      icon: Icons.movie_creation,
      iconColor: Colors.deepPurple,
    ),
    OnboardingPage(
      title: 'Swipe to Discover',
      description:
          '👆 Tap for movie details\n👍 Swipe right to mark as watched\n👎 Swipe left to skip\n🔖 Swipe down to bookmark',
      icon: Icons.swipe,
      iconColor: Colors.blue,
      showGestureDemo: true,
    ),
    OnboardingPage(
      title: 'Two Movie Feeds',
      description:
          '🎬 Trending: Popular movies everyone loves\n💡 For You: Personalized recommendations based on your taste and ratings',
      icon: Icons.tab,
      iconColor: Colors.green,
    ),
    OnboardingPage(
      title: 'Smart Filtering',
      description:
          '🎭 Filter by genre (Action, Comedy, Horror...)\n🌍 Filter by language (English, Spanish, French...)\n📅 Filter by year (2020s, 2010s, 2000s...)\n🎭 Filter by streaming platform (Netflix, Prime, Disney+)',
      icon: Icons.filter_list,
      iconColor: Colors.orange,
    ),
    OnboardingPage(
      title: 'Track Your Movies',
      description:
          '📚 Bookmarks: Save movies to watch later\n👁️ Watched: Your movie history with ratings\n⭐ Rate movies 1-10 stars\n👥 Share with friends (coming soon)',
      icon: Icons.bookmark,
      iconColor: Colors.amber,
    ),
    OnboardingPage(
      title: 'Ready to Start!',
      description:
          'Start swiping to discover amazing movies. Your preferences will be saved automatically, and recommendations will get better over time.',
      icon: Icons.play_arrow,
      iconColor: Colors.green,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    // Sign in anonymously if not already signed in
    if (widget.authService.currentUser == null) {
      await widget.authService.signInAnonymously();
    }
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: _skipOnboarding,
                  child: const Text(
                    'Skip',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index]);
                },
              ),
            ),

            // Page indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        _currentPage == index
                            ? Colors.deepPurple
                            : Colors.white24,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: const Text(
                        'Back',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    )
                  else
                    const SizedBox.shrink(),

                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: Text(
                      _currentPage == _pages.length - 1
                          ? 'Get Started'
                          : 'Next',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: page.iconColor.withValues(alpha: 0.2),
            ),
            child: Icon(page.icon, size: 60, color: page.iconColor),
          ),

          const SizedBox(height: 48),

          // Title
          Text(
            page.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Description
          Text(
            page.description,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          // Gesture demo for swipe page
          if (page.showGestureDemo) ...[
            const SizedBox(height: 32),
            _buildGestureDemo(),
          ],
        ],
      ),
    );
  }

  Widget _buildGestureDemo() {
    return Container(
      padding: const EdgeInsets.all(12), // Reduced padding
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          const Text(
            'Try these gestures:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8), // Reduced spacing

          // Gesture indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildGestureIcon(Icons.arrow_back, 'Skip', Colors.red),
              _buildGestureIcon(Icons.arrow_forward, 'Watch', Colors.green),
            ],
          ),
          const SizedBox(height: 4), // Reduced spacing
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildGestureIcon(Icons.arrow_upward, 'Details', Colors.blue),
              _buildGestureIcon(Icons.arrow_downward, 'Bookmark', Colors.amber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGestureIcon(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 28, // Smaller icon container
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.2),
          ),
          child: Icon(icon, color: color, size: 14), // Smaller icon
        ),
        const SizedBox(height: 2), // Reduced spacing
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withAlpha(230), // Brighter text
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class OnboardingPage {
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final bool showGestureDemo;

  OnboardingPage({
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    this.showGestureDemo = false,
  });
}
