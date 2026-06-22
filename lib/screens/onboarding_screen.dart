library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants.dart';
import '../core/hive_boxes.dart';
import '../widgets/grain_overlay.dart';
import 'camera_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const _pages = [
    _OnboardingPage(
      icon: Icons.camera_alt_rounded,
      title: RetroStrings.onboardTitle1,
      body: RetroStrings.onboardBody1,
      gradient: [Color(0xFFFF6200), Color(0xFFCC4E00)],
    ),
    _OnboardingPage(
      icon: Icons.camera_roll_rounded,
      title: RetroStrings.onboardTitle2,
      body: RetroStrings.onboardBody2,
      gradient: [Color(0xFFFFD600), Color(0xFFFF9100)],
    ),
    _OnboardingPage(
      icon: Icons.auto_awesome_rounded,
      title: RetroStrings.onboardTitle3,
      body: RetroStrings.onboardBody3,
      gradient: [Color(0xFFE91E63), Color(0xFFFF6200)],
    ),
  ];

  void _onNext() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() {
    HiveService.setOnboardingComplete();
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const CameraScreen()));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RetroColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: GrainOverlay(opacity: 0.04)),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.18),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.40),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: RetroColors.surface.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(RetroDimens.radiusXl),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Text(
                      'RETROLAB',
                      style: GoogleFonts.spaceMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: RetroColors.accent,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_currentPage + 1}/${_pages.length}',
                    style: GoogleFonts.spaceMono(
                      fontSize: 11,
                      color: RetroColors.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
          PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (context, index) {
              final page = _pages[index];
              return _buildPage(page, index);
            },
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(RetroDimens.paddingLg),
                child: Container(
                  padding: const EdgeInsets.all(RetroDimens.paddingMd),
                  decoration: BoxDecoration(
                    color: RetroColors.surface.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (i) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _currentPage ? 28 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color:
                                  i == _currentPage
                                      ? RetroColors.accent
                                      : RetroColors.surfaceLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _currentPage == _pages.length - 1
                            ? 'You are ready to shoot.'
                            : 'Swipe or continue through the setup.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: RetroColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _onNext,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                RetroDimens.radiusXl,
                              ),
                            ),
                          ),
                          child: Text(
                            _currentPage == _pages.length - 1
                                ? 'START SHOOTING'
                                : 'NEXT',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (_currentPage < _pages.length - 1)
                        TextButton(
                          onPressed: _completeOnboarding,
                          child: Text(
                            'SKIP',
                            style: GoogleFonts.spaceMono(
                              fontSize: 12,
                              color: RetroColors.textMuted,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RetroDimens.paddingXl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(RetroDimens.paddingLg),
            decoration: BoxDecoration(
              color: RetroColors.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(RetroDimens.radiusLg),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: page.gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: page.gradient[0].withValues(alpha: 0.4),
                        blurRadius: 40,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(page.icon, size: 52, color: Colors.white),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: page.gradient.first.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(RetroDimens.radiusXl),
                    border: Border.all(
                      color: page.gradient.first.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Text(
                    'STEP ${index + 1}',
                    style: GoogleFonts.spaceMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: page.gradient.first,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  page.title,
                  style: GoogleFonts.spaceMono(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: RetroColors.textPrimary,
                    letterSpacing: 1,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  page.body,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: RetroColors.textSecondary,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String body;
  final List<Color> gradient;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.body,
    required this.gradient,
  });
}
