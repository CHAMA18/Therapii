import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:therapii/pages/therapist_inspiration_page.dart';
import 'package:therapii/widgets/primary_button.dart';

class TherapistPracticePersonalizationPage extends StatefulWidget {
  const TherapistPracticePersonalizationPage({super.key});

  @override
  State<TherapistPracticePersonalizationPage> createState() => _TherapistPracticePersonalizationPageState();
}

class _TherapistPracticePersonalizationPageState extends State<TherapistPracticePersonalizationPage> {
  final _addressingController = TextEditingController();
  final _customPhraseController = TextEditingController();
  final _otherConcernController = TextEditingController();

  final List<String> _phraseOptions = [
    'Tell me more',
    "I'm struck by...",
    'How does it feel to sit with...',
    "Let's revisit...",
  ];

  final List<String> _engagementOptions = [
    'Mostly Listen',
    'Actively Solicit Information',
    'Make Suggestions',
  ];

  final List<String> _concernOptions = [
    "The chatbot doesn't 'feel like me'",
    "My patients won't want to pay for it",
    'The chatbot feels "too much like me"',
    "My patients won't want to use it",
    'The chatbot makes bad recommendations',
    'Ensuring data privacy',
    'The chatbot fails to pick up danger signals',
    'Other (please describe)',
  ];

  final Set<String> _selectedPhrases = {};
  final Set<String> _selectedConcerns = {};

  String? _selectedEngagement;
  bool _showCustomPhraseField = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  @override
  void dispose() {
    _addressingController.dispose();
    _customPhraseController.dispose();
    _otherConcernController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('therapists').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final addressingStyle = data['client_addressing_style'];
        final phrases = List<String>.from(data['preferred_phrases_options'] ?? const []);
        final customPhrase = data['preferred_phrases_custom'];
        final engagement = data['default_ai_engagement'];
        final concerns = List<String>.from(data['patient_ai_concerns'] ?? const []);
        final otherConcern = data['patient_ai_concern_other'];

        if (addressingStyle is String && addressingStyle.isNotEmpty) {
          _addressingController.text = addressingStyle;
        }

        _selectedPhrases.clear();
        for (final phrase in phrases) {
          if (!_phraseOptions.contains(phrase)) {
            _phraseOptions.add(phrase);
          }
          _selectedPhrases.add(phrase);
        }

        if (customPhrase is String && customPhrase.isNotEmpty) {
          _customPhraseController.text = customPhrase;
          if (!_phraseOptions.contains(customPhrase)) {
            _selectedPhrases.add(customPhrase);
          }
          _showCustomPhraseField = true;
        }

        if (engagement is String && engagement.isNotEmpty) {
          _selectedEngagement = engagement;
        }

        _selectedConcerns
          ..clear()
          ..addAll(concerns);

        if (otherConcern is String && otherConcern.isNotEmpty) {
          _otherConcernController.text = otherConcern;
          if (!_selectedConcerns.contains('Other (please describe)')) {
            _selectedConcerns.add('Other (please describe)');
          }
        }
      }
    } catch (_) {
      // Keep the UI responsive even if loading fails.
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _togglePhrase(String value) {
    setState(() {
      if (_selectedPhrases.contains(value)) {
        _selectedPhrases.remove(value);
      } else {
        _selectedPhrases.add(value);
      }
    });
  }

  void _toggleEngagement(String value) {
    setState(() {
      if (_selectedEngagement == value) {
        _selectedEngagement = null;
      } else {
        _selectedEngagement = value;
      }
    });
  }

  void _toggleConcern(String value) {
    final isSelected = _selectedConcerns.contains(value);
    if (isSelected) {
      setState(() {
        _selectedConcerns.remove(value);
        if (value == 'Other (please describe)' && _selectedConcerns.contains('Other (please describe)') == false) {
          _otherConcernController.clear();
        }
      });
      return;
    }

    if (_selectedConcerns.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select up to three concerns.')),
      );
      return;
    }

    setState(() => _selectedConcerns.add(value));
  }

  Future<void> _saveAndContinue() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be signed in to continue.')),
      );
      return;
    }

    final addressingStyle = _addressingController.text.trim();
    final customPhrase = _customPhraseController.text.trim();
    final otherConcern = _otherConcernController.text.trim();

    if (addressingStyle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe how you typically address clients.')),
      );
      return;
    }

    final selectedPhrases = Set<String>.from(_selectedPhrases);
    if (customPhrase.isNotEmpty) {
      selectedPhrases.add(customPhrase);
    }

    if (selectedPhrases.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one phrase.')),
      );
      return;
    }

    if (_selectedEngagement == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose how the AI should engage with patients.')),
      );
      return;
    }

    if (_selectedConcerns.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one concern.')),
      );
      return;
    }

    if (_selectedConcerns.contains('Other (please describe)') && otherConcern.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe your other concern.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance.collection('therapists').doc(user.uid).set(
        {
          'client_addressing_style': addressingStyle,
          'preferred_phrases_options': selectedPhrases.toList(),
          'preferred_phrases_custom': customPhrase.isNotEmpty ? customPhrase : FieldValue.delete(),
          'default_ai_engagement': _selectedEngagement,
          'patient_ai_concerns': _selectedConcerns.toList(),
          'patient_ai_concern_other': _selectedConcerns.contains('Other (please describe)')
              ? otherConcern
              : FieldValue.delete(),
          'practice_personalization_completed_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TherapistInspirationPage()),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save your preferences. ${e.message ?? e.code}')),
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

  Widget _buildCheckboxTile({
    required String label,
    required bool value,
    required VoidCallback onChanged,
  }) {
    return CheckboxListTile(
      value: value,
      onChanged: (_) => onChanged(),
      title: Text(label),
      activeColor: const Color(0xFF3565B0),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextButton.icon(
                    onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                    label: const Text('Back'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF1F2839),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'About your Practice',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1F2839),
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Answer these questions to help personalize your AI agent to behave more like you. The following questions will be used to begin training your AI agent. There are no wrong answers here, but the more information you provide the more accurately the agent will be able to reflect your practice, your personality and your style. Completing this should not take more than five minutes.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF475467),
                          height: 1.5,
                        ),
                  ),
                  const SizedBox(height: 32),
                  _QuestionCard(
                    title:
                        'How do you typically address a client? i.e. First name, Mr/Mrs, something more casual, or maybe it depends on the client?',
                    child: TextField(
                      controller: _addressingController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Describe your typical approach to addressing clients...',
                        filled: true,
                        fillColor: const Color(0xFFF9FAFB),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFF3565B0)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _QuestionCard(
                    title:
                        'Which of the following turns of phrase are you likely to use when trying to get a client to open up and share some information?',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ..._phraseOptions.map(
                          (phrase) => _buildCheckboxTile(
                            label: phrase,
                            value: _selectedPhrases.contains(phrase),
                            onChanged: () => _togglePhrase(phrase),
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() => _showCustomPhraseField = true);
                          },
                          child: Text(
                            'Add another personal phrase',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF3565B0),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _showCustomPhraseField || _customPhraseController.text.isNotEmpty
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: TextField(
                                    key: const ValueKey('custom_phrase'),
                                    controller: _customPhraseController,
                                    decoration: InputDecoration(
                                      hintText: 'Enter your personal phrase...',
                                      filled: true,
                                      fillColor: const Color(0xFFF9FAFB),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(color: Color(0xFF3565B0)),
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _QuestionCard(
                    title:
                        'As a default setting, how would you like the AI chatbot to engage with your patients (you can change this per patient)?',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ..._engagementOptions.map(
                          (option) => _buildCheckboxTile(
                            label: option,
                            value: _selectedEngagement == option,
                            onChanged: () => _toggleEngagement(option),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _QuestionCard(
                    title:
                        'What things are you most concerned about with your patients using the AI chatbot? We think that they are all important, but we want to know what you think? Please select up to three',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ..._concernOptions.map(
                          (concern) => _buildCheckboxTile(
                            label: concern,
                            value: _selectedConcerns.contains(concern),
                            onChanged: () => _toggleConcern(concern),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _otherConcernController,
                          maxLines: 2,
                          enabled: _selectedConcerns.contains('Other (please describe)'),
                          decoration: InputDecoration(
                            hintText: 'Please describe your other concern...',
                            filled: true,
                            fillColor: const Color(0xFFF9FAFB),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF3565B0)),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: 'Continue',
                    uppercase: false,
                    isLoading: _saving,
                    onPressed: _saving ? null : _saveAndContinue,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1F2839),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F101828),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: titleStyle),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}