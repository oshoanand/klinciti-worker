import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/router/route_names.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback?
  onFinish; // Optional callback; defaults to context.go(AppRoutes.home)

  const OnboardingScreen({super.key, this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Worker-focused 2-screen onboarding content
  final List _pages = [
    {
      'title': 'Стабильный доход\nпо вашему графику',
      'subtitle': 'Принимайте заказы на уборку, ремонт, курьерскую доставку или вывоз мусора в удобное для вас время рядом с домом.',
      'icon': Icons.access_alarm_outlined,
      'image': 'assets/images/worker_onboarding_1.webp',
      'color': const Color(0xFF3B82F6), // Blue
    },
    {
      'title': 'Быстрый старт и\nчестные выплаты',
      'subtitle': 'Заполните анкету за 5 минут, выберите свои категории услуг и получайте оплату за каждый выполненный заказ.',
      'icon': Icons.account_balance_wallet_rounded,
      'image': 'assets/images/worker_onboarding_2.webp',
      'color': const Color(0xFF10B981), // Emerald
    },
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);

    if (!mounted) return;

    if (widget.onFinish != null) {
      widget.onFinish!();
    } else {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _onNext() async {
    if (_currentPage == _pages.length - 1) {
      await _completeOnboarding();
    } else {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.fastOutSlowIn,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Make status bar transparent for edge-to-edge design
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
      ),
    );

    final bool isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate base
      body: Stack(
        children: [
          // 1. Swipeable Background & Content (with parallax)
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              final page = _pages[index];
              return _buildPageContent(
                index: index,
                title: page['title'] as String,
                subtitle: page['subtitle'] as String,
                icon: page['icon'] as IconData,
                color: page['color'] as Color,
                imagePath: page['image'] as String,
              );
            },
          ),

          // 2. Fixed Skip Button (Top Right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 24,
            child: IgnorePointer(
              ignoring: isLastPage,
              child: AnimatedOpacity(
                opacity: isLastPage ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 300),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: const Text(
                    'Пропустить',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Fixed Bottom Section (Indicators & CTA Button)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 32,
                right: 32,
                top: 32,
                bottom: MediaQuery.of(context).padding.bottom + 32,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Dot Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => _buildDot(index),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // CTA Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0F172A),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        isLastPage ? 'Начать зарабатывать' : 'Далее',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageContent({
    required int index,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String imagePath,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        double pageOffset = index.toDouble();
        if (_pageController.position.haveDimensions) {
          pageOffset = _pageController.page ?? index.toDouble();
        }

        // difference is 0 when fully visible, grows to 1 or -1 as it swipes away
        final double difference = (pageOffset - index).clamp(-1.0, 1.0);

        // Foreground Text: Fade out and slide down slightly
        final double textOpacity = (1.0 - difference.abs()).clamp(0.0, 1.0);
        final double textTranslateY = difference.abs() * 50.0;

        // Background Image: Horizontal parallax (moves 30% of swipe width)
        final double imageTranslateX = difference * screenWidth * 0.3;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Background Image with Horizontal Parallax
            Transform.translate(
              offset: Offset(imageTranslateX, 0),
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Container(color: color),
              ),
            ),

            // Translucent Theme Tint
            Container(color: color.withValues(alpha: 0.35)),

            // Dark elegant gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF0F172A).withValues(alpha: 0.5),
                    const Color(0xFF0F172A).withValues(alpha: 0.95),
                    const Color(0xFF0F172A),
                  ],
                  stops: const [0.0, 0.45, 0.75, 1.0],
                ),
              ),
            ),

            // Foreground Content with Vertical Parallax and Fade
            Opacity(
              opacity: textOpacity,
              child: Transform.translate(
                offset: Offset(0, textTranslateY),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Glassmorphism Icon Container
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(icon, size: 70, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Typography
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 34,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),

                      // Spacing to keep content above the fixed bottom section
                      const SizedBox(height: 200),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDot(int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index
            ? Colors.white
            : Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
