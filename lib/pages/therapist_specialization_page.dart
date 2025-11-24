import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:therapii/pages/therapist_practice_personalization_page.dart';
import 'package:therapii/widgets/primary_button.dart';

class TherapistSpecializationPage extends StatefulWidget {
  const TherapistSpecializationPage({super.key});

  @override
  State<TherapistSpecializationPage> createState() => _TherapistSpecializationPageState();
}

class _TherapistSpecializationPageState extends State<TherapistSpecializationPage> {
  final List<String> _specializationOptions = [
    'Addiction',
    'ADHD',
    'Anger Management',
    'Bipolar Disorder',
    'Chronic Pain',
    'Obsessive Compulsive',
    'Grief',
    'Transition Issues',
  ];

  String? _selectedSpecialization;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingSelection();
  }

  Future<void> _loadExistingSelection() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('therapists').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final specialization = data['specialization'];
        if (specialization is String && specialization.isNotEmpty) {
          _selectedSpecialization = specialization;
          if (!_specializationOptions.contains(specialization)) {
            _specializationOptions.add(specialization);
          }
        }
      }
    } catch (_) {
      // Keep page usable even if we fail to prefill.
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _selectSpecialization(String value) {
    setState(() {
      _selectedSpecialization = value;
    });
  }

  Future<void> _saveAndFinish() async {
    if (_selectedSpecialization == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a specialization to continue.')),
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
      await FirebaseFirestore.instance.collection('therapists').doc(user.uid).set(
        {
          'specialization': _selectedSpecialization,
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TherapistPracticePersonalizationPage()),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save your selection. ${e.message ?? e.code}')),
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

  Widget _buildChip(String value) {
    final bool isSelected = _selectedSpecialization == value;
    return GestureDetector(
      onTap: () => _selectSpecialization(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        constraints: const BoxConstraints(minWidth: 140),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3765B0) : const Color(0xFFF3F6FB),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF344054),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                  label: const Text('Back'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1F2839),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Select the area of specialization that best describe your practice',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1F2839),
                    ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: SingleChildScrollView(
                  child: Center(
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final option in _specializationOptions) _buildChip(option),
                      ],
                    ),
                  ),
                ),
              ),
              PrimaryButton(
                label: 'Continue',
                uppercase: false,
                isLoading: _saving,
                onPressed: _saving ? null : _saveAndFinish,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
