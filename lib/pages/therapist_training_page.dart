import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import '../services/openai_trainer.dart';
import 'package:therapii/pages/my_patients_page.dart';
import 'package:therapii/widgets/primary_button.dart';

class TherapistTrainingPage extends StatefulWidget {
  const TherapistTrainingPage({super.key});

  @override
  State<TherapistTrainingPage> createState() => _TherapistTrainingPageState();
}

// Predefined avatar options for AI personas
const List<_AvatarOption> _avatarOptions = [
  _AvatarOption(icon: Icons.psychology, color: Color(0xFF5C6BC0), label: 'Mindful'),
  _AvatarOption(icon: Icons.favorite, color: Color(0xFFEC407A), label: 'Caring'),
  _AvatarOption(icon: Icons.spa, color: Color(0xFF26A69A), label: 'Calm'),
  _AvatarOption(icon: Icons.lightbulb, color: Color(0xFFFFB300), label: 'Insightful'),
  _AvatarOption(icon: Icons.healing, color: Color(0xFF42A5F5), label: 'Healing'),
  _AvatarOption(icon: Icons.self_improvement, color: Color(0xFF7E57C2), label: 'Balanced'),
  _AvatarOption(icon: Icons.wb_sunny, color: Color(0xFFFF7043), label: 'Warm'),
  _AvatarOption(icon: Icons.nature_people, color: Color(0xFF66BB6A), label: 'Grounded'),
];

class _AvatarOption {
  final IconData icon;
  final Color color;
  final String label;
  const _AvatarOption({required this.icon, required this.color, required this.label});
}

class _TherapistTrainingPageState extends State<TherapistTrainingPage> {
  final TextEditingController _nameController = TextEditingController();
  final PageController _avatarPageController = PageController(viewportFraction: 0.4, initialPage: 0);
  int _selectedAvatarIndex = 0;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  Future<void> _loadExistingData() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('therapists').doc(user.uid).get();
      if (!doc.exists) return;

      final data = doc.data();
      if (data == null) return;

      final profile = data['ai_training_profile'];
      if (profile is Map<String, dynamic>) {
        final name = profile['name'];
        if (name is String && name.isNotEmpty) {
          _nameController.text = name;
        }

        final avatarIndex = profile['avatar_index'];
        if (avatarIndex is int && avatarIndex >= 0 && avatarIndex < _avatarOptions.length) {
          _selectedAvatarIndex = avatarIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _avatarPageController.hasClients) {
              _avatarPageController.jumpToPage(avatarIndex);
            }
          });
        }
      }
    } catch (_) {
      // Non-fatal: keep screen responsive even if load fails.
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _onAvatarChanged(int index) {
    setState(() => _selectedAvatarIndex = index);
  }

  Future<void> _handleStartTraining() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be signed in to continue.')),
      );
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please give your AI a name before starting training.')),
      );
      return;
    }

    setState(() => _saving = true);

    final docRef = FirebaseFirestore.instance.collection('therapists').doc(user.uid);

    try {
      final snapshot = await docRef.get();
      final existingData = snapshot.data() ?? <String, dynamic>{};

      final selectedAvatar = _avatarOptions[_selectedAvatarIndex];
      final aiProfilePayload = <String, dynamic>{
        'name': name,
        'avatar_index': _selectedAvatarIndex,
        'avatar_icon': selectedAvatar.icon.codePoint,
        'avatar_color': selectedAvatar.color.value,
        'avatar_label': selectedAvatar.label,
      };

      await docRef.set(
        {
          'ai_training_profile': aiProfilePayload,
          'ai_training_profile_updated_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      final combinedData = Map<String, dynamic>.from(existingData)
        ..['ai_training_profile'] = {
          'name': name,
          'avatar_label': selectedAvatar.label,
        };

      final prompt = _buildTrainingPrompt(
        aiName: name,
        therapistData: combinedData,
      );

      final trainer = const OpenAITrainer();
      final trainingResult = await trainer.trainTherapistProfile(prompt: prompt);

      await docRef.set(
        {
          'ai_training_result': {
            'response_id': trainingResult.responseId,
            'model': trainingResult.model,
            'summary': trainingResult.outputText,
            if (trainingResult.usage != null) 'usage': trainingResult.usage,
            'completed_at': FieldValue.serverTimestamp(),
          },
          'ai_training_last_completed_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MyPatientsPage()),
        (route) => false,
      );
    } on OpenAIConfigurationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } on OpenAIRequestException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Training failed: ${e.message}')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start training. ${e.message ?? e.code}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _buildTrainingPrompt({
    required String aiName,
    required Map<String, dynamic> therapistData,
  }) {
    final buffer = StringBuffer();

    final aiProfile = therapistData['ai_training_profile'];
    final avatarStyle = aiProfile is Map<String, dynamic> ? _normalizeString(aiProfile['avatar_label']) : null;

    final therapistName = _normalizeString(therapistData['full_name']);
    final practiceName = _normalizeString(therapistData['practice_name']);
    final city = _normalizeString(therapistData['city']);
    final state = _normalizeString(therapistData['state']);
    final zip = _normalizeString(therapistData['zip_code']);
    final email = _normalizeString(therapistData['contact_email']);
    final phone = _normalizeString(therapistData['contact_phone']);
    final profileUrl = _normalizeString(therapistData['psychology_today_url']);
    final hasPsychologyProfile = therapistData['has_psychology_today_profile'];

    final locationParts = [
      if (city != null) city,
      if (state != null) state,
      if (zip != null) zip,
    ];

    final overviewLines = <String>[
      'AI persona name: $aiName',
      if (therapistName != null) 'Therapist: $therapistName',
      if (practiceName != null) 'Practice: $practiceName',
      if (locationParts.isNotEmpty) 'Location: ${locationParts.join(', ')}',
      if (email != null) 'Contact email: $email',
      if (phone != null) 'Contact phone: $phone',
      if (avatarStyle != null) 'Avatar personality style: $avatarStyle',
    ];

    if (hasPsychologyProfile is bool) {
      if (hasPsychologyProfile) {
        overviewLines.add(
          profileUrl != null
              ? 'Psychology Today profile: $profileUrl'
              : 'Psychology Today profile on file (URL not provided).',
        );
      } else {
        overviewLines.add('No Psychology Today profile available.');
      }
    } else if (profileUrl != null) {
      overviewLines.add('Psychology Today profile: $profileUrl');
    }

    _appendBulletSection(buffer, 'Therapist Persona Overview', overviewLines);

    final licensure = _normalizeStringList(therapistData['state_licensures']);
    final education = _normalizeStringList(therapistData['educations']);
    final credentialsLines = <String>[
      if (licensure.isNotEmpty) 'Licensed in: ${licensure.join(', ')}',
      if (education.isNotEmpty) 'Education: ${education.join('; ')}',
    ];
    _appendBulletSection(buffer, 'Credentials', credentialsLines);

    final methodologies = _normalizeStringList(therapistData['methodologies']);
    final specialties = _normalizeStringList(therapistData['specialties']);
    final models = _normalizeStringList(therapistData['therapeutic_models']);
    final specialization = _normalizeString(therapistData['specialization']);
    final clinicalLines = <String>[
      if (specialization != null) 'Primary specialization: $specialization',
      if (methodologies.isNotEmpty) 'Methodologies: ${methodologies.join(', ')}',
      if (specialties.isNotEmpty) 'Specialties: ${specialties.join(', ')}',
      if (models.isNotEmpty) 'Therapeutic models: ${models.join(', ')}',
    ];
    _appendBulletSection(buffer, 'Clinical Focus', clinicalLines);

    final addressStyle = _normalizeString(therapistData['client_addressing_style']);
    final phrases = _normalizeStringList(therapistData['preferred_phrases_options']);
    final customPhrase = _normalizeString(therapistData['preferred_phrases_custom']);
    final defaultEngagement = _normalizeString(therapistData['default_ai_engagement']);
    final communicationLines = <String>[
      if (addressStyle != null) 'Addresses clients as: $addressStyle',
      if (phrases.isNotEmpty) 'Frequent prompts: ${phrases.join('; ')}',
      if (customPhrase != null) 'Personal catchphrase: $customPhrase',
      if (defaultEngagement != null) 'Default engagement style: $defaultEngagement',
    ];
    _appendBulletSection(buffer, 'Communication Preferences', communicationLines);

    final concerns = _normalizeStringList(therapistData['patient_ai_concerns']);
    final otherConcern = _normalizeString(therapistData['patient_ai_concern_other']);
    final safetyLines = <String>[
      ...concerns,
      if (otherConcern != null) 'Other concern: $otherConcern',
    ];
    _appendBulletSection(buffer, 'Safety & Risk Priorities', safetyLines);

    final inspirationLines = _buildInspirationLines(therapistData['practice_inspiration_profiles']);
    _appendBulletSection(buffer, 'Inspirations & References', inspirationLines);

    buffer.writeln('Output Expectations:');
    buffer.writeln('- Structure sections as: Voice & Tone, Therapeutic Focus, Engagement Preferences, Safety Priorities, Inspirations.');
    buffer.writeln('- Use concise bullet points with actionable guidance tailored to the therapist.');
    buffer.writeln('- Keep the brief under 250 words and avoid generic platitudes.');
    buffer.writeln('- Highlight how the AI should sound, what approaches to emphasize, and the guardrails to respect.');
    return buffer.toString().trim();
  }

  void _appendBulletSection(StringBuffer buffer, String title, Iterable<String> lines) {
    final entries = lines.where((line) => line.trim().isNotEmpty).toList();
    if (entries.isEmpty) {
      return;
    }
    buffer.writeln('$title:');
    for (final line in entries) {
      buffer.writeln('- $line');
    }
    buffer.writeln();
  }

  String? _normalizeString(dynamic raw) {
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  List<String> _normalizeStringList(dynamic raw) {
    if (raw is Iterable) {
      final seen = <String>{};
      for (final item in raw) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final qualification = _normalizeString(map['qualification']);
          final institution = _normalizeString(map['institution'] ?? map['university']);
          final yearRaw = map['year_completed'];
          String? yearString;
          if (yearRaw is int) {
            yearString = yearRaw.toString();
          } else if (yearRaw is String) {
            yearString = yearRaw.trim().isEmpty ? null : yearRaw.trim();
          }
          final parts = <String>[];
          if (qualification != null) parts.add(qualification);
          if (institution != null && institution.toLowerCase() != (qualification ?? '').toLowerCase()) {
            parts.add(institution);
          }
          if (yearString != null) {
            parts.add('Completed $yearString');
          }
          if (parts.isNotEmpty) {
            seen.add(parts.join(' • '));
            continue;
          }
          final fallback = map.values.firstWhere(
            (value) => value is String && value.toString().trim().isNotEmpty,
            orElse: () => null,
          );
          if (fallback is String) {
            final normalizedFallback = _normalizeString(fallback);
            if (normalizedFallback != null) {
              seen.add(normalizedFallback);
            }
          }
          continue;
        }

        final value = _normalizeString(item);
        if (value != null) {
          seen.add(value);
        }
      }
      return seen.toList();
    }
    return [];
  }

  List<String> _buildInspirationLines(dynamic raw) {
    if (raw is! Iterable) {
      return [];
    }

    final lines = <String>[];
    for (final entry in raw) {
      if (entry is Map) {
        final note = _normalizeString(entry['note']);
        final linksRaw = entry['links'];
        final linkParts = <String>[];

        if (linksRaw is Map) {
          linksRaw.forEach((key, value) {
            if (key is String) {
              final normalizedLink = _normalizeString(value);
              if (normalizedLink != null) {
                linkParts.add('$key: $normalizedLink');
              }
            }
          });
        }

        final parts = <String>[
          if (note != null) 'Note: $note',
          if (linkParts.isNotEmpty) 'Links -> ${linkParts.join(', ')}',
        ];

        if (parts.isNotEmpty) {
          lines.add(parts.join('; '));
        }
      }
    }

    return lines;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _avatarPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxHeight = constraints.maxHeight;
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: math.max(0, maxHeight - 64)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 32),
                    Text(
                      'Therapist Training',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF3565B0),
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'To begin customizing your experience, please name your AI and select a profile picture. '
                      'This personalized profile will be used for all your patients. We will then have a conversation '
                      'to help the AI understand your unique therapeutic style and approach.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFF3F4C63),
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Avatar carousel
                    SizedBox(
                      height: 160,
                      child: PageView.builder(
                        controller: _avatarPageController,
                        onPageChanged: _onAvatarChanged,
                        itemCount: _avatarOptions.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final avatar = _avatarOptions[index];
                          final isSelected = index == _selectedAvatarIndex;
                          return AnimatedScale(
                            scale: isSelected ? 1.0 : 0.75,
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            child: AnimatedOpacity(
                              opacity: isSelected ? 1.0 : 0.5,
                              duration: const Duration(milliseconds: 200),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          avatar.color.withValues(alpha: 0.9),
                                          avatar.color,
                                        ],
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: avatar.color.withValues(alpha: 0.4),
                                                blurRadius: 20,
                                                spreadRadius: 2,
                                              ),
                                            ]
                                          : null,
                                      border: Border.all(
                                        color: isSelected ? Colors.white : Colors.transparent,
                                        width: 3,
                                      ),
                                    ),
                                    child: Icon(
                                      avatar.icon,
                                      size: 44,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    avatar.label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                      color: isSelected ? avatar.color : const Color(0xFF9AA7C7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // Swipe hint
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chevron_left, size: 20, color: const Color(0xFFB0BEC5)),
                        const SizedBox(width: 4),
                        Text(
                          'Swipe to choose avatar',
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF9AA7C7),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, size: 20, color: const Color(0xFFB0BEC5)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _nameController,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        hintText: 'Give your AI a name',
                        hintStyle: const TextStyle(color: Color(0xFF9AA7C7)),
                        filled: true,
                        fillColor: const Color(0xFFF3F6FC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: const BorderSide(color: Color(0xFF3565B0), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: PrimaryButton(
                        label: 'Start Training',
                        uppercase: true,
                        isLoading: _saving,
                        onPressed: _saving ? null : _handleStartTraining,
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}