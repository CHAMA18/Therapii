import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:therapii/pages/therapist_details_page.dart';
import 'package:therapii/widgets/primary_button.dart';

class TherapistWelcomePsychologyTodayPage extends StatefulWidget {
  const TherapistWelcomePsychologyTodayPage({super.key});

  @override
  State<TherapistWelcomePsychologyTodayPage> createState() => _TherapistWelcomePsychologyTodayPageState();
}

class _TherapistWelcomePsychologyTodayPageState extends State<TherapistWelcomePsychologyTodayPage> {
  final TextEditingController _urlCtrl = TextEditingController();
  bool _noProfile = false;
  bool _submitting = false;
  final _formKey = GlobalKey<FormState>();

  // Accept only Psychology Today profile URLs across regions.
  // Valid examples:
  // - https://www.psychologytoday.com/us/therapists/jane-doe-boston-ma/123456
  // - https://www.psychologytoday.com/gb/counsellors/john-smith-london/987654
  // - psychologytoday.com/us/psychiatrists/...
  bool _isValidPsychologyTodayProfile(String input) {
    final text = input.trim();
    if (text.isEmpty) return false;

    // Add a default scheme for parsing if missing
    final normalized = text.startsWith('http') ? text : 'https://$text';
    final uri = Uri.tryParse(normalized);
    if (uri == null || uri.host.isEmpty) return false;

    // Host must be psychologytoday.com (optionally with www.)
    final host = uri.host.toLowerCase();
    final isPsyTodayHost = host == 'psychologytoday.com' || host == 'www.psychologytoday.com';
    if (!isPsyTodayHost) return false;

    // Path should indicate a person profile, not a generic page
    final segments = uri.pathSegments.map((s) => s.toLowerCase()).toList();
    final hasProfileContext = segments.contains('therapists') ||
        segments.contains('counsellors') ||
        segments.contains('psychiatrists') ||
        segments.contains('profile');
    if (!hasProfileContext) return false;

    // Require at least one non-empty segment after the context to avoid top-level listings
    final idx = segments.indexWhere((s) => s == 'therapists' || s == 'counsellors' || s == 'psychiatrists' || s == 'profile');
    if (idx == -1 || idx == segments.length - 1) return false;

    return true;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    // Validate inputs: if a profile is required, ensure it is a Psychology Today profile URL
    if (!_noProfile) {
      final isValid = _formKey.currentState?.validate() ?? false;
      if (!isValid) return;
    }

    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You need to be signed in to continue.')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final docRef = FirebaseFirestore.instance.collection('therapists').doc(user.uid);
      final existingSnapshot = await docRef.get();

      final data = <String, dynamic>{
        'user_id': user.uid,
        'has_psychology_today_profile': !_noProfile,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (_noProfile) {
        data['psychology_today_url'] = FieldValue.delete();
      } else {
        // Normalize to https scheme when saving
        final raw = _urlCtrl.text.trim();
        final normalized = raw.startsWith('http') ? raw : 'https://$raw';
        data['psychology_today_url'] = normalized;
      }

      if (!existingSnapshot.exists) {
        data['created_at'] = FieldValue.serverTimestamp();
      }

      await docRef.set(data, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TherapistDetailsPage()),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save your details. Please try again. (${e.message ?? e.code})')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  // Therapii logo placed above the section text
                  Center(
                    child: Image.asset(
                      'assets/images/therapii_logo.png',
                      height: 64,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF28C50), // soft orange badge
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Congratulations', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Congratulations, and welcome to therapy!!',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'The first step is to complete your Therapist profile on Psychology Today. Enter the URL below and we will pre‑populate your profile as best we can.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _urlCtrl,
                    enabled: !_noProfile,
                    decoration: const InputDecoration(
                      hintText: 'psychologytoday.com/us/therapists/your-name-city-state/123456',
                      labelText: 'Psychology Today profile URL',
                    ),
                    validator: (value) {
                      if (_noProfile) return null; // Skip when no profile
                      final v = (value ?? '').trim();
                      if (v.isEmpty) {
                        return 'Please enter your Psychology Today profile URL or select the checkbox.';
                      }
                      if (!_isValidPsychologyTodayProfile(v)) {
                        return 'Enter a valid Psychology Today profile link (psychologytoday.com/...)';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _noProfile,
                        onChanged: (v) => setState(() {
                          _noProfile = v ?? false;
                          // Re-run validation to clear or show errors appropriately
                          _formKey.currentState?.validate();
                        }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            "I don't have a Psychology Today profile",
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: 'Continue',
                    isLoading: _submitting,
                    onPressed: _submitting ? null : _continue,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}
