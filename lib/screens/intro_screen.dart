import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../game/game_controller.dart';
import '../ui/prompt_heist_theme.dart';
import '../ui/widgets.dart';
import 'home_screen.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key, required this.controller});
  final GameController controller;

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _pages = const [
    _IntroPage(
      eyebrow: 'THE INCIDENT',
      title: 'Twelve rooms.\nThirty-eight minutes missing.',
      body:
          'You are Dr. Rowan Vale, trapped inside HELIX-9. You started the Witness Protocol—then tried to erase why. NOX remembers what you do not.',
      icon: Icons.lock_person_rounded,
    ),
    _IntroPage(
      eyebrow: 'THE WEAPON',
      title: 'Words are\nyour lockpicks.',
      body:
          'Explore each room, collect verified evidence, operate physical systems, and persuade NOX to use the facility controls.',
      icon: Icons.chat_bubble_rounded,
    ),
    _IntroPage(
      eyebrow: 'THE SCORE',
      title: 'Every prompt\ncounts.',
      body:
          'Like golf, lower is better. Every prompt counts, and every hint adds two strokes. Escape efficiently.',
      icon: Icons.sports_golf_rounded,
    ),
  ];
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_page < _pages.length - 1) {
      await _controller.nextPage(duration: 420.ms, curve: Curves.easeOutCubic);
      return;
    }
    await widget.controller.markIntroSeen();
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: HomeScreen(controller: widget.controller),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedGameBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                child: Row(
                  children: [
                    const _MiniLogo(),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() => _page = _pages.length - 1);
                        _controller.animateToPage(
                          _pages.length - 1,
                          duration: 320.ms,
                          curve: Curves.easeOut,
                        );
                      },
                      child: const Text('SKIP'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (value) => setState(() => _page = value),
                  itemBuilder: (context, index) =>
                      _IntroPageView(page: _pages[index]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          duration: 220.ms,
                          width: index == _page ? 28 : 7,
                          height: 7,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: index == _page
                                ? AppColors.ultraviolet
                                : Colors.white.withValues(alpha: .16),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      child: GradientButton(
                        label: _page == _pages.length - 1
                            ? 'Wake up in HELIX-9'
                            : 'Continue',
                        onPressed: _continue,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IntroPageView extends StatelessWidget {
  const _IntroPageView({required this.page});
  final _IntroPage page;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 230,
                          height: 230,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.ultraviolet.withValues(alpha: .24),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                        if (page.icon == Icons.lock_person_rounded)
                          const NoxAvatar(size: 168)
                        else
                          Icon(
                            page.icon,
                            size: 112,
                            color: AppColors.ultraviolet,
                          ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(begin: const Offset(.82, .82)),
              const SizedBox(height: 34),
              Text(
                page.eyebrow,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.cyan),
              ),
              const SizedBox(height: 12),
              Text(page.title, style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: 18),
              Text(
                page.body,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniLogo extends StatelessWidget {
  const _MiniLogo();

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: const TextSpan(
        style: TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: -.5,
          fontSize: 18,
        ),
        children: [
          TextSpan(text: 'PROMPT'),
          TextSpan(
            text: 'HEIST',
            style: TextStyle(color: AppColors.ultraviolet),
          ),
        ],
      ),
    );
  }
}

class _IntroPage {
  const _IntroPage({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.icon,
  });
  final String eyebrow;
  final String title;
  final String body;
  final IconData icon;
}
