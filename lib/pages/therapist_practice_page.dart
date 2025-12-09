import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:therapii/pages/therapist_therapeutic_models_page.dart';
import 'package:therapii/widgets/primary_button.dart';

class TherapistPracticePage extends StatefulWidget {
  const TherapistPracticePage({super.key});

  @override
  State<TherapistPracticePage> createState() => _TherapistPracticePageState();
}

class _TherapistPracticePageState extends State<TherapistPracticePage> {
  final List<String> _methodologyOptions = [
    'IFS (Internal Family Systems)',
    'CBT (Cognitive Behavioral Therapy)',
    'Acceptance and Commitment',
    'EMDR',
    'Attachment Theory',
    'Gestalt',
    'Biofeedback',
    'Brainspotting',
    'Christian Counseling',
    'CBT (Cognitive and Behavioral Therapy)',
    'Compassion Focused',
    'CPT (Cognitive Processing Therapy)',
    'DBT (Dialectic Behavior Therapy)',
  ];

  final List<String> _specialtyOptions = [
    'Adoption',
    'Addiction',
    'ADHD',
    'Adult Children of Alcoholics',
    'Alcohol Use',
    'Anger Management',
    'Antisocial Personality',
    'Anxiety',
    'Assessment for Attention Deficit Disorder',
    'Assistance with Gender Equality',
    'Attachment Trauma',
    'Autism',
    'Behavioral Issues',
    'Bipolar Disorder',
    'Bisexual',
    'Body Positivity',
  ];

  final Set<String> _selectedMethodologies = {};
  final Set<String> _selectedSpecialties = {};

  bool _termsAccepted = false;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('therapists').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final existingMethodologies = List<String>.from(data['methodologies'] ?? const []);
        final existingSpecialties = List<String>.from(data['specialties'] ?? const []);

        for (final item in existingMethodologies) {
          if (!_methodologyOptions.contains(item)) {
            _methodologyOptions.add(item);
          }
        }

        for (final item in existingSpecialties) {
          if (!_specialtyOptions.contains(item)) {
            _specialtyOptions.add(item);
          }
        }

        _selectedMethodologies
          ..clear()
          ..addAll(existingMethodologies);
        _selectedSpecialties
          ..clear()
          ..addAll(existingSpecialties);
        _termsAccepted = data['terms_accepted'] == true;
      }
    } catch (_) {
      // ignore load errors but keep UI usable
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _addCustomMethodology() => _promptForCustomValue('Add another methodology', (value) {
        setState(() {
          _methodologyOptions.add(value);
          _selectedMethodologies.add(value);
        });
      });

  Future<void> _addCustomSpecialty() => _promptForCustomValue('Add another specialty', (value) {
        setState(() {
          _specialtyOptions.add(value);
          _selectedSpecialties.add(value);
        });
      });

  Future<void> _promptForCustomValue(String title, void Function(String value) onSubmit) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter value'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                Navigator.of(dialogContext).pop(text);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (value != null && value.isNotEmpty) {
      onSubmit(value);
    }
  }

  void _toggleMethodology(String value) {
    setState(() {
      if (_selectedMethodologies.contains(value)) {
        _selectedMethodologies.remove(value);
      } else {
        _selectedMethodologies.add(value);
      }
    });
  }

  void _toggleSpecialty(String value) {
    setState(() {
      if (_selectedSpecialties.contains(value)) {
        _selectedSpecialties.remove(value);
      } else {
        _selectedSpecialties.add(value);
      }
    });
  }

  Future<void> _logout() async {
    try {
      await firebase_auth.FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to log out right now. Please try again.')),
      );
    }
  }

  Future<void> _saveAndContinue() async {
    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please agree to the terms and conditions to continue.')),
      );
      return;
    }

    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be signed in to continue.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final data = <String, dynamic>{
        'methodologies': _selectedMethodologies.toList(),
        'specialties': _selectedSpecialties.toList(),
        'terms_accepted': _termsAccepted,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (_termsAccepted) {
        data['terms_accepted_at'] = FieldValue.serverTimestamp();
      } else {
        data['terms_accepted_at'] = FieldValue.delete();
      }

      await FirebaseFirestore.instance.collection('therapists').doc(user.uid).set(
            data,
            SetOptions(merge: true),
          );

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TherapistTherapeuticModelsPage()),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save your selections. ${e.message ?? e.code}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildChipGroup({
    required List<String> options,
    required Set<String> selectedValues,
    required void Function(String value) onTap,
  }) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(option),
            selected: selectedValues.contains(option),
            onSelected: (_) => onTap(option),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            selectedColor: const Color(0xFF3765B0),
            backgroundColor: const Color(0xFFF2F4F8),
            labelStyle: TextStyle(
              color: selectedValues.contains(option) ? Colors.white : const Color(0xFF354052),
              fontWeight: FontWeight.w600,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Practice Setup'),
        centerTitle: true,
        actions: [
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Logout'),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 28),
                  Text(
                    'About your Practice',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Methodologies',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '(Select all that apply)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black.withOpacity(0.6)),
                  ),
                  const SizedBox(height: 20),
                  _buildChipGroup(
                    options: _methodologyOptions,
                    selectedValues: _selectedMethodologies,
                    onTap: _toggleMethodology,
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _addCustomMethodology,
                    child: Text(
                      'Add another methodology',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    'Specialties/Expertise',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '(Select all that apply)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black.withOpacity(0.6)),
                  ),
                  const SizedBox(height: 20),
                  _buildChipGroup(
                    options: _specialtyOptions,
                    selectedValues: _selectedSpecialties,
                    onTap: _toggleSpecialty,
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _addCustomSpecialty,
                    child: Text(
                      'Add another specialty',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: scheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Checkbox(
                        value: _termsAccepted,
                        onChanged: (value) => setState(() => _termsAccepted = value ?? false),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'I agree to the terms and conditions',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: 'Continue',
                          onPressed: _saving ? null : _saveAndContinue,
                          isLoading: _saving,
                          uppercase: false,
                        ),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
                        child: Text(
                          'Go Back',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
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
