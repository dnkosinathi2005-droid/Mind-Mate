import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../services/affirmation_service.dart';

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final firstName = user?.displayName?.split(' ').first ?? 'Friend';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$greeting,',
                              style: AppTextStyles.bodyMedium,
                            ),
                            Text(
                              firstName,
                              style: AppTextStyles.displayMedium,
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => context.push(AppConstants.routeProfile),
                          child: _Avatar(user: user),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Daily affirmation card
                    _AffirmationCard(),
                    const SizedBox(height: 28),

                    Text(
                      'What would you like to do?',
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Quick action grid
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.05,
                children: const [
                  _ActionCard(
                    emoji: '📓',
                    title: 'Journal',
                    subtitle: 'Write your thoughts',
                    gradient: [Color(0xFF9B7DD4), Color(0xFF7C5CBF)],
                    route: AppConstants.routeJournal,
                  ),
                  _ActionCard(
                    emoji: '🎭',
                    title: 'Mood',
                    subtitle: 'Track how you feel',
                    gradient: [Color(0xFF4ECDC4), Color(0xFF2BA8A0)],
                    route: AppConstants.routeMood,
                  ),
                  _ActionCard(
                    emoji: '💬',
                    title: 'Chat',
                    subtitle: 'Talk to your companion',
                    gradient: [Color(0xFF80E8E2), Color(0xFF4ECDC4)],
                    route: AppConstants.routeChatbot,
                  ),
                  _ActionCard(
                    emoji: '🧘',
                    title: 'Meditate',
                    subtitle: 'Calm your mind',
                    gradient: [Color(0xFFB39DDB), Color(0xFF9B7DD4)],
                    route: AppConstants.routeMeditation,
                  ),
                  _ActionCard(
                    emoji: '📚',
                    title: 'Resources',
                    subtitle: 'Affirmations & sounds',
                    gradient: [Color(0xFF81C784), Color(0xFF4CAF50)],
                    route: AppConstants.routeResources,
                  ),
                  _ActionCard(
                    emoji: '🔔',
                    title: 'Reminders',
                    subtitle: 'Set daily alerts',
                    gradient: [Color(0xFFFFB74D), Color(0xFFFFA726)],
                    route: '/alerts',
                  ),
                ],
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// ── Avatar widget ─────────────────────────────
class _Avatar extends StatelessWidget {
  final User? user;
  const _Avatar({this.user});

  @override
  Widget build(BuildContext context) {
    final photoUrl = user?.photoURL;
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.surfaceVariant,
      backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
      child: photoUrl == null
          ? Text(
              (user?.displayName?.isNotEmpty == true)
                  ? user!.displayName![0].toUpperCase()
                  : '?',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.primary,
              ),
            )
          : null,
    );
  }
}

// ── Daily affirmation card ────────────────────
class _AffirmationCard extends StatefulWidget {
  const _AffirmationCard();

  @override
  State<_AffirmationCard> createState() => _AffirmationCardState();
}

class _AffirmationCardState extends State<_AffirmationCard> {
  String _affirmation = 'Loading your daily affirmation...';
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    AffirmationService.instance.getTodayAffirmation().then((text) {
      if (mounted) setState(() { _affirmation = text; _loaded = true; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final affirmation = _affirmation;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.splashGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                'Daily affirmation',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedOpacity(
            opacity: _loaded ? 1.0 : 0.6,
            duration: const Duration(milliseconds: 400),
            child: Text(
              affirmation,
              style: AppTextStyles.bodyLarge.copyWith(
                color: Colors.white,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick action card ─────────────────────────
class _ActionCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final String route;

  const _ActionCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(route),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
