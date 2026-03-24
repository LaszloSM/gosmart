// lib/features/onboarding/intro_screen.dart
// Pantallas de introducción — 3 slides con PageView animado
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0;

  static const _slides = [
    _Slide(
      icon: Icons.map_rounded,
      title: 'Planifica tu ruta',
      description:
          'Encuentra la mejor manera de llegar a tu destino. '
          'Compara transporte público y privado en tiempo real con IA.',
      gradientColors: [Color(0xFF5CFD80), Color(0xFF02C953)],
    ),
    _Slide(
      icon: Icons.account_balance_wallet_rounded,
      title: 'Paga fácil',
      description:
          'Recarga tu tarjeta GoSmart y paga en cualquier sistema '
          'de transporte con un solo toque. Sin efectivo.',
      gradientColors: [Color(0xFF45FEC9), Color(0xFF00A08A)],
    ),
    _Slide(
      icon: Icons.smart_toy_rounded,
      title: 'Asistente IA',
      description:
          'Pregúntale a GoSmart AI sobre rutas, tarifas y horarios. '
          'Tu experto en movilidad urbana en Colombia.',
      gradientColors: [Color(0xFF6C63FF), Color(0xFF3B35C4)],
    ),
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _slides.length - 1) {
      _pageCtrl.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _continue();
    }
  }

  void _skip() => _continue();

  void _continue() => context.go('/location-permission');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: GSSpacing.s3,
                  right: GSSpacing.s4,
                ),
                child: TextButton(
                  onPressed: _skip,
                  child: const Text(
                    'Omitir',
                    style: TextStyle(
                      color: GSColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
            // Slides
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _SlideContent(slide: _slides[i]),
              ),
            ),
            // Dots indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: GSSpacing.s4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? GSColors.accent
                          : GSColors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(GSRadius.full),
                    ),
                  );
                }),
              ),
            ),
            // Button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                GSSpacing.s5,
                0,
                GSSpacing.s5,
                GSSpacing.s5,
              ),
              child: GSButton(
                label: _currentPage == _slides.length - 1
                    ? 'Comenzar'
                    : 'Siguiente',
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Slide data class ──────────────────────────────────────────────────────────

class _Slide {
  final IconData icon;
  final String title;
  final String description;
  final List<Color> gradientColors;

  const _Slide({
    required this.icon,
    required this.title,
    required this.description,
    required this.gradientColors,
  });
}

// ── Slide content widget ──────────────────────────────────────────────────────

class _SlideContent extends StatelessWidget {
  final _Slide slide;
  const _SlideContent({super.key, required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icono con gradiente circular
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: slide.gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: slide.gradientColors[0].withValues(alpha: 0.35),
                  blurRadius: 36,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Icon(slide.icon, size: 72, color: Colors.black),
          ),
          const SizedBox(height: GSSpacing.s8),
          // Título
          Text(
            slide.title,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: GSColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: GSSpacing.s4),
          // Descripción
          Text(
            slide.description,
            style: const TextStyle(
              fontSize: 16,
              color: GSColors.textSecondary,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
