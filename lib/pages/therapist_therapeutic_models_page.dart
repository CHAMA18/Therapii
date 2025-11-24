import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:therapii/pages/therapist_specialization_page.dart';
import 'package:therapii/widgets/primary_button.dart';

class TherapistTherapeuticModelsPage extends StatefulWidget {
  const TherapistTherapeuticModelsPage({super.key});

  @override
  State<TherapistTherapeuticModelsPage> createState() => _TherapistTherapeuticModelsPageState();
}

class _TherapistTherapeuticModelsPageState extends State<TherapistTherapeuticModelsPage> {
  final List<String> _modelOptions = [
    'IFS (Internal Family Systems)',
    'CBT (Cognitive Behavioral Therapy)',
    'Attachment Theory',
    'Acceptance and Commitment',
    'EMDR',
  ];

  final Set<String> _selectedModels = {};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExistingSelections();
  }

  Future<void> _loadExistingSelections() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('therapists').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        final existing = List<String>.from(data['therapeutic_models'] ?? const []);
        for (final value in existing) {
          if (!_modelOptions.contains(value)) {
            _modelOptions.add(value);
          }
        }
        _selectedModels
          ..clear()
          ..addAll(existing);
      }
    } catch (_) {
      // allow users to continue even if we fail to prefill
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _toggleModel(String value) {
    setState(() {
      if (_selectedModels.contains(value)) {
        _selectedModels.remove(value);
      } else {
        _selectedModels.add(value);
      }
    });
  }

  Future<void> _saveAndContinue() async {
    if (_selectedModels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one model to continue.')),
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
              'therapeutic_models': _selectedModels.toList(),
              'updated_at': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TherapistSpecializationPage()),
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

  Widget _buildModelChip(String value) {
    final bool isSelected = _selectedModels.contains(value);
    return GestureDetector(
      onTap: () => _toggleModel(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        constraints: const BoxConstraints(minWidth: 140),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3765B0) : const Color(0xFFE2E6EF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF3F4A5A),
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
                'Which of these therapeutic models you employ?',
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
                        for (final model in _modelOptions) _buildModelChip(model),
                      ],
                    ),
                  ),
                ),
              ),
              PrimaryButton(
                label: 'Continue',
                uppercase: false,
                isLoading: _saving,
                onPressed: _saving ? null : _saveAndContinue,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}