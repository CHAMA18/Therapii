import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import 'package:therapii/models/user.dart' as app_user;
import 'package:therapii/services/user_service.dart';
import 'package:therapii/widgets/common_settings_drawer.dart';
import 'package:therapii/widgets/dashboard_action_card.dart';
import 'package:therapii/pages/my_patients_page.dart';
import 'package:therapii/pages/listen_page.dart';
import 'package:therapii/pages/therapist_details_page.dart';
import 'package:therapii/pages/therapist_practice_personalization_page.dart';
import 'package:therapii/pages/therapist_therapeutic_models_page.dart';
import 'package:therapii/pages/support_center_page.dart';
import 'package:therapii/pages/billing_page.dart';

class TherapistDashboardPage extends StatefulWidget {
  const TherapistDashboardPage({super.key});

  @override
  State<TherapistDashboardPage> createState() => _TherapistDashboardPageState();
}

class _TherapistDashboardPageState extends State<TherapistDashboardPage> {
  final _userService = UserService();
  app_user.User? _therapist;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final authUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      setState(() {
        _loading = false;
        _error = 'You must be signed in.';
      });
      return;
    }

    try {
      final u = await _userService.getUser(authUser.uid);
      if (!mounted) return;
      setState(() {
        _therapist = u;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load your profile. $e';
        _loading = false;
      });
    }
  }

  String _displayName() {
    final u = _therapist;
    if (u == null) return 'Therapist';
    if (u.firstName.trim().isNotEmpty) return u.firstName.trim();
    if (u.fullName.trim().isNotEmpty) return u.fullName.trim();
    return u.email.split('@').first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget body;
    if (_loading) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error, size: 40),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    } else {
      final name = _displayName();

      body = SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 36),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _greeting() + ',',
                              style: theme.textTheme.headlineMedium?.copyWith(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Text(
                              name,
                              style: theme.textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSurface,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'What would you like to do today?',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'T',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Action grid
                LayoutBuilder(builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  final gap = isWide ? 24.0 : 20.0;

                  List<Widget> columnChildren() => [
                        // Row 1
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: DashboardActionCard(
                                  title: 'My Patients',
                                  subtitle: 'Manage conversations, invite new patients',
                                  icon: Icons.groups_rounded,
                                  isPrimary: true,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const MyPatientsPage()),
                                  ),
                                ),
                              ),
                              SizedBox(width: gap),
                              Expanded(
                                child: DashboardActionCard(
                                  title: 'Listen',
                                  subtitle: 'AI summaries, transcripts and voice updates',
                                  icon: Icons.graphic_eq_rounded,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const ListenPage()),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else ...[
                          DashboardActionCard(
                            title: 'My Patients',
                            subtitle: 'Manage conversations, invite new patients',
                            icon: Icons.groups_rounded,
                            isPrimary: true,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const MyPatientsPage()),
                            ),
                          ),
                          SizedBox(height: gap),
                          DashboardActionCard(
                            title: 'Listen',
                            subtitle: 'AI summaries, transcripts and voice updates',
                            icon: Icons.graphic_eq_rounded,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const ListenPage()),
                            ),
                          ),
                        ],

                        SizedBox(height: gap),
                        // Row 2
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: DashboardActionCard(
                                  title: 'Practice Setup',
                                  subtitle: 'Contact & Licensure, Education, ID verification',
                                  icon: Icons.badge_outlined,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const TherapistDetailsPage()),
                                  ),
                                ),
                              ),
                              SizedBox(width: gap),
                              Expanded(
                                child: DashboardActionCard(
                                  title: 'Personalization',
                                  subtitle: 'Tone, phrases, engagement & concerns',
                                  icon: Icons.tune_rounded,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const TherapistPracticePersonalizationPage()),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else ...[
                          DashboardActionCard(
                            title: 'Practice Setup',
                            subtitle: 'Contact & Licensure, Education, ID verification',
                            icon: Icons.badge_outlined,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const TherapistDetailsPage()),
                            ),
                          ),
                          SizedBox(height: gap),
                          DashboardActionCard(
                            title: 'Personalization',
                            subtitle: 'Tone, phrases, engagement & concerns',
                            icon: Icons.tune_rounded,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const TherapistPracticePersonalizationPage()),
                            ),
                          ),
                        ],

                        SizedBox(height: gap),
                        // Row 3
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: DashboardActionCard(
                                  title: 'Therapeutic Models',
                                  subtitle: 'Core approaches for your practice',
                                  icon: Icons.psychology_alt_outlined,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const TherapistTherapeuticModelsPage()),
                                  ),
                                ),
                              ),
                              SizedBox(width: gap),
                              Expanded(
                                child: DashboardActionCard(
                                  title: 'Billing',
                                  subtitle: 'Manage subscription and invoices',
                                  icon: Icons.credit_card_rounded,
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const BillingPage()),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else ...[
                          DashboardActionCard(
                            title: 'Therapeutic Models',
                            subtitle: 'Core approaches for your practice',
                            icon: Icons.psychology_alt_outlined,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const TherapistTherapeuticModelsPage()),
                            ),
                          ),
                          SizedBox(height: gap),
                          DashboardActionCard(
                            title: 'Billing',
                            subtitle: 'Manage subscription and invoices',
                            icon: Icons.credit_card_rounded,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const BillingPage()),
                            ),
                          ),
                        ],

                        SizedBox(height: gap),
                        // Row 4
                        DashboardActionCard(
                          title: 'Support Center',
                          subtitle: 'FAQs and help resources',
                          icon: Icons.help_center_rounded,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SupportCenterPage()),
                          ),
                        ),
                      ];

                  return Column(children: columnChildren());
                }),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.settings_rounded),
          tooltip: 'Settings',
          onPressed: () => showSettingsPopup(context),
        ),
      ),
      body: body,
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
