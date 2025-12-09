import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:therapii/pages/therapist_training_page.dart';
import 'package:therapii/widgets/primary_button.dart';

class TherapistInspirationPage extends StatefulWidget {
  const TherapistInspirationPage({super.key});

  @override
  State<TherapistInspirationPage> createState() => _TherapistInspirationPageState();
}

class _TherapistInspirationPageState extends State<TherapistInspirationPage> {
  final List<_InspirationBlockData> _blocks = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _initialiseBlocks();
  }

  void _initialiseBlocks() {
    _blocks.clear();
    _blocks.add(_InspirationBlockData(includeNoteField: true));
    _blocks.add(_InspirationBlockData());
    _blocks.add(_InspirationBlockData());
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
      if (!doc.exists) {
        setState(() => _loading = false);
        return;
      }

      final data = doc.data() ?? {};
      final raw = data['practice_inspiration_profiles'];
      if (raw is List) {
        final rawBlocks = raw.cast<Map<dynamic, dynamic>>();
        if (rawBlocks.isNotEmpty) {
          for (final block in _blocks) {
            block.dispose();
          }
          _blocks.clear();

          for (var i = 0; i < rawBlocks.length; i++) {
            final map = rawBlocks[i];
            final noteValue = map['note'];
            final includeNote = i == 0 || (noteValue is String && noteValue.trim().isNotEmpty);
            final blockData = _InspirationBlockData(includeNoteField: includeNote);

            if (blockData.noteController != null && noteValue is String) {
              blockData.noteController!.text = noteValue;
            }

            final linksValue = map['links'];
            if (linksValue is Map) {
              for (final platform in _SocialPlatform.values) {
                final dynamic rawLink = linksValue[platform.storageKey];
                if (rawLink is String && rawLink.isNotEmpty) {
                  blockData.controllers[platform]!.text = rawLink;
                }
              }
            }

            _blocks.add(blockData);
          }

          if (_blocks.isEmpty || _blocks.first.noteController == null) {
            _blocks.insert(0, _InspirationBlockData(includeNoteField: true));
          }
          while (_blocks.length < 3) {
            _blocks.add(_InspirationBlockData());
          }
        }
      }
    } catch (_) {
      // Keep UI responsive on failure.
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveAndContinue() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be signed in to continue.')),
      );
      return;
    }

    final List<Map<String, dynamic>> payloadBlocks = [];

    for (final block in _blocks) {
      final links = <String, String>{};
      for (final platform in _SocialPlatform.values) {
        final controller = block.controllers[platform];
        if (controller == null) continue;
        final value = controller.text.trim();
        if (value.isNotEmpty) {
          links[platform.storageKey] = value;
        }
      }

      final note = block.noteController?.text.trim() ?? '';
      if (links.isEmpty && note.isEmpty) {
        continue;
      }

      payloadBlocks.add({
        if (note.isNotEmpty) 'note': note,
        if (links.isNotEmpty) 'links': links,
      });
    }

    if (payloadBlocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please share at least one inspiration link or note before continuing.')),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await FirebaseFirestore.instance.collection('therapists').doc(user.uid).set(
        {
          'practice_inspiration_profiles': payloadBlocks,
          'practice_inspiration_completed_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TherapistTrainingPage()),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save your inspirations. ${e.message ?? e.code}')),
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

  void _handleClearField(TextEditingController controller) {
    controller.clear();
    setState(() {});
  }

  @override
  void dispose() {
    for (final block in _blocks) {
      block.dispose();
    }
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
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('AI Personalization'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Answer these questions to help personalize your Therapist agent to behave more like you',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1F2839),
                        ),
                  ),
                  const SizedBox(height: 16),
                  for (var index = 0; index < _blocks.length; index++)
                    _buildBlock(index, _blocks[index]),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _saving ? null : () => Navigator.of(context).maybePop(),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF1F2839),
                          textStyle: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        child: const Text('Go Back'),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 160,
                        child: PrimaryButton(
                          label: 'Continue',
                          uppercase: false,
                          isLoading: _saving,
                          onPressed: _saving ? null : _saveAndContinue,
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

  Widget _buildBlock(int index, _InspirationBlockData block) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE4E7EC)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F101828),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Who are the therapists or leaders in your field that most inspire you and your practice?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1F2839),
                ),
          ),
          if (block.noteController != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: block.noteController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Share the names or stories of the people that influence your work...',
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
          ],
          const SizedBox(height: 14),
          for (final platform in _SocialPlatform.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SocialLinkField(
                platform: platform,
                controller: block.controllers[platform]!,
                onClear: () => _handleClearField(block.controllers[platform]!),
              ),
            ),
        ],
      ),
    );
  }
}

class _SocialLinkField extends StatelessWidget {
  const _SocialLinkField({
    required this.platform,
    required this.controller,
    required this.onClear,
  });

  final _SocialPlatform platform;
  final TextEditingController controller;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E7EC)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: platform.backgroundColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: FaIcon(
              platform.icon,
              color: platform.iconColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: platform.placeholder,
                hintStyle: const TextStyle(color: Color(0xFF98A2B3)),
                border: InputBorder.none,
              ),
            ),
          ),
          TextButton(
            onPressed: onClear,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF3565B0),
              textStyle: const TextStyle(fontWeight: FontWeight.w600),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _InspirationBlockData {
  _InspirationBlockData({bool includeNoteField = false})
      : noteController = includeNoteField ? TextEditingController() : null,
        controllers = {
          for (final platform in _SocialPlatform.values) platform: TextEditingController(),
        };

  final TextEditingController? noteController;
  final Map<_SocialPlatform, TextEditingController> controllers;

  void dispose() {
    noteController?.dispose();
    for (final controller in controllers.values) {
      controller.dispose();
    }
  }
}

enum _SocialPlatform {
  instagram,
  twitter,
  tiktok,
  youtube,
  facebook,
  linkedin,
}

extension on _SocialPlatform {
  String get storageKey => switch (this) {
        _SocialPlatform.instagram => 'instagram',
        _SocialPlatform.twitter => 'twitter',
        _SocialPlatform.tiktok => 'tiktok',
        _SocialPlatform.youtube => 'youtube',
        _SocialPlatform.facebook => 'facebook',
        _SocialPlatform.linkedin => 'linkedin',
      };

  String get placeholder => switch (this) {
        _SocialPlatform.instagram => 'Enter Instagram URL',
        _SocialPlatform.twitter => 'Enter Twitter URL',
        _SocialPlatform.tiktok => 'Enter TikTok URL',
        _SocialPlatform.youtube => 'Enter YouTube URL',
        _SocialPlatform.facebook => 'Enter FaceBook URL',
        _SocialPlatform.linkedin => 'Enter LinkedIn URL',
      };

  IconData get icon => switch (this) {
        _SocialPlatform.instagram => FontAwesomeIcons.instagram,
        _SocialPlatform.twitter => FontAwesomeIcons.xTwitter,
        _SocialPlatform.tiktok => FontAwesomeIcons.tiktok,
        _SocialPlatform.youtube => FontAwesomeIcons.youtube,
        _SocialPlatform.facebook => FontAwesomeIcons.facebookF,
        _SocialPlatform.linkedin => FontAwesomeIcons.linkedinIn,
      };

  Color get backgroundColor => switch (this) {
        _SocialPlatform.instagram => const Color(0xFFE1306C),
        _SocialPlatform.twitter => Colors.black,
        _SocialPlatform.tiktok => const Color(0xFF000000),
        _SocialPlatform.youtube => const Color(0xFFFE0000),
        _SocialPlatform.facebook => const Color(0xFF1877F2),
        _SocialPlatform.linkedin => const Color(0xFF0A66C2),
      };

  Color get iconColor => switch (this) {
        _SocialPlatform.instagram => Colors.white,
        _SocialPlatform.twitter => Colors.white,
        _SocialPlatform.tiktok => Colors.white,
        _SocialPlatform.youtube => Colors.white,
        _SocialPlatform.facebook => Colors.white,
        _SocialPlatform.linkedin => Colors.white,
      };
}