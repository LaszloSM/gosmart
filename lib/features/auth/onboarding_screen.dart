import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../router/app_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _page = PageController();
  int _current = 0;

  static const _slides = [
    _Slide(
      icon: Icons.route_rounded,
      color: GSColors.primary,
      title: 'One card,\nevery route',
      body:
          'Bus, metro, bike, taxi — all connected in one smart transit card powered by AI.',
    ),
    _Slide(
      icon: Icons.account_balance_wallet_rounded,
      color: GSColors.eco,
      title: 'Instant top-up,\nzero friction',
      body:
          'Recharge in seconds with any payment method. Tap your phone or card on any validator.',
    ),
    _Slide(
      icon: Icons.eco_rounded,
      color: GSColors.eco,
      title: 'Travel smarter,\nlive greener',
      body:
          'Track your CO₂ savings and earn Eco Points every time you choose sustainable transport.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _page,
                onPageChanged: (i) => setState(() => _current = i),
                itemCount: _slides.length,
                itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
              ),
            ),
            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: GSDuration.normal,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _current == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color:
                        _current == i ? GSColors.primary : GSColors.border,
                    borderRadius: BorderRadius.circular(GSRadius.full),
                  ),
                ),
              ),
            ),
            const SizedBox(height: GSSpacing.s8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s6),
              child: Column(
                children: [
                  GSButton(
                    label: _current < _slides.length - 1
                        ? 'Continue'
                        : 'Get Started',
                    onPressed: () {
                      if (_current < _slides.length - 1) {
                        _page.nextPage(
                          duration: GSDuration.page,
                          curve: Curves.easeInOut,
                        );
                      } else {
                        context.go(AppRoutes.login);
                      }
                    },
                  ),
                  const SizedBox(height: GSSpacing.s3),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.login),
                    child: const Text('Already have an account? Sign in'),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.home),
                    child: const Text('Skip — explore demo',
                        style: TextStyle(color: GSColors.textSecondary,
                            fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: GSSpacing.s6),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(GSSpacing.s6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: slide.color.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(slide.icon, size: 80, color: slide.color),
          ),
          const SizedBox(height: GSSpacing.s10),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displaySmall,
          ),
          const SizedBox(height: GSSpacing.s4),
          Text(
            slide.body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: GSColors.textSecondary,
                  height: 1.6,
                ),
          ),
        ],
      ),
    );
  }
}

class _Slide {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  const _Slide({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });
}
