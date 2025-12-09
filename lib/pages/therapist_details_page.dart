import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:therapii/data/universities.dart';
import 'package:therapii/pages/therapist_practice_page.dart';
import 'package:therapii/widgets/primary_button.dart';

class EducationEntry {
  final String qualification;
  final String university;
  final String? institutionOverride;
  final int? yearCompleted;

  const EducationEntry({
    required this.qualification,
    required this.university,
    this.institutionOverride,
    this.yearCompleted,
  });

  String get resolvedInstitution {
    final lower = university.toLowerCase().trim();
    if (lower == 'others' || lower == 'other') {
      return (institutionOverride ?? '').trim();
    }
    return university.trim();
  }

  String get displayLabel {
    final parts = <String>[
      qualification.trim(),
      if (resolvedInstitution.isNotEmpty) resolvedInstitution,
      if (yearCompleted != null) 'Completed $yearCompleted',
    ];
    return parts.where((element) => element.isNotEmpty).join(' • ');
  }

  Map<String, dynamic> toJson() => {
        'qualification': qualification.trim(),
        'university': university.trim(),
        'institution': resolvedInstitution,
        'year_completed': yearCompleted,
      }..removeWhere((key, value) => value == null || (value is String && value.isEmpty));

  static EducationEntry fromJson(Map<String, dynamic> json) {
    final university = (json['university'] ?? json['institution'] ?? '').toString();
    int? year;
    final rawYear = json['year_completed'];
    if (rawYear is int) {
      year = rawYear;
    } else if (rawYear is String) {
      year = int.tryParse(rawYear);
    } else {
      year = null;
    }
    return EducationEntry(
      qualification: (json['qualification'] ?? json['degree'] ?? json['title'] ?? '').toString(),
      university: university,
      institutionOverride: json['institution'] != null && json['institution'] != university ? json['institution'].toString() : json['institution_override']?.toString(),
      yearCompleted: year,
    );
  }

  static EducationEntry fromLegacyString(String value) {
    final trimmed = value.trim();
    return EducationEntry(
      qualification: trimmed,
      university: 'Others',
      institutionOverride: trimmed,
      yearCompleted: null,
    );
  }

  EducationEntry copyWith({
    String? qualification,
    String? university,
    String? institutionOverride,
    int? yearCompleted,
  }) {
    return EducationEntry(
      qualification: qualification ?? this.qualification,
      university: university ?? this.university,
      institutionOverride: institutionOverride ?? this.institutionOverride,
      yearCompleted: yearCompleted ?? this.yearCompleted,
    );
  }
}

class TherapistDetailsPage extends StatefulWidget {
  const TherapistDetailsPage({super.key});

  @override
  State<TherapistDetailsPage> createState() => _TherapistDetailsPageState();
}

class _TherapistDetailsPageState extends State<TherapistDetailsPage> {
  int _currentPage = 0;
  final PageController _pageController = PageController();

  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _practiceCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _stateCtrl = TextEditingController();
  final TextEditingController _zipCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  String? _profilePhotoUrl;
  String? _qualificationUrl;
  String? _idPhotoUrl;

  bool _isUploadingProfile = false;
  bool _isUploadingQualification = false;
  bool _isUploadingId = false;

  final List<String> _stateLicensures = [];
  final List<EducationEntry> _educations = [];

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadExistingData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _practiceCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _zipCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExistingData() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('therapists').doc(user.uid).get();
      if (!doc.exists) return;
      final data = doc.data() ?? <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = (data['full_name'] ?? '').toString();
        _practiceCtrl.text = (data['practice_name'] ?? '').toString();
        _cityCtrl.text = (data['city'] ?? '').toString();
        _stateCtrl.text = (data['state'] ?? '').toString();
        _zipCtrl.text = (data['zip_code'] ?? '').toString();
        _emailCtrl.text = (data['contact_email'] ?? '').toString();
        _phoneCtrl.text = (data['contact_phone'] ?? '').toString();
        
        _profilePhotoUrl = data['profile_photo_url'] as String?;
        _qualificationUrl = data['qualification_file_url'] as String?;
        _idPhotoUrl = data['id_photo_url'] as String?;

        _stateLicensures
          ..clear()
          ..addAll(List<String>.from(data['state_licensures'] ?? const <String>[]));
        _educations
          ..clear()
          ..addAll(_decodeEducationEntries(data));
      });
    } catch (_) {
      // ignore onboarding load errors; the user can still input fresh data
    }
  }

  Future<void> _continue() async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You need to be signed in to continue.')),
      );
      return;
    }

    if (_profilePhotoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a profile photo.')),
      );
      return;
    }
    if (_qualificationUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload your qualification document.')),
      );
      return;
    }
    if (_idPhotoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a photo of your ID.')),
      );
      return;
    }

    final docRef = FirebaseFirestore.instance.collection('therapists').doc(user.uid);
    setState(() => _submitting = true);
    try {
      final snapshot = await docRef.get();

      final educationSummaries = _educations.map((e) => e.displayLabel).toList(growable: false);
      final educationEntries = _educations.map((e) => e.toJson()).toList(growable: false);

      final data = <String, dynamic>{
        'user_id': user.uid,
        'full_name': _nameCtrl.text.trim(),
        'practice_name': _practiceCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'zip_code': _zipCtrl.text.trim(),
        'contact_email': _emailCtrl.text.trim(),
        'contact_phone': _phoneCtrl.text.trim(),
        'profile_photo_url': _profilePhotoUrl,
        'qualification_file_url': _qualificationUrl,
        'id_photo_url': _idPhotoUrl,
        'state_licensures': _stateLicensures,
        'educations': educationSummaries,
        'education_entries': educationEntries,
        'updated_at': FieldValue.serverTimestamp(),
      };

      if (!snapshot.exists) {
        data['created_at'] = FieldValue.serverTimestamp();
      }

      final existingStatus = (snapshot.data()?['approval_status'] as String?)?.toLowerCase();
      if (existingStatus == 'approved') {
        data['approval_status'] = 'approved';
      } else {
        data['approval_status'] = 'pending';
        data['approval_requested_at'] = FieldValue.serverTimestamp();
        data['approved_at'] = FieldValue.delete();
        data['approved_by'] = FieldValue.delete();
        data['approved_by_email'] = FieldValue.delete();
      }

      await docRef.set(data, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TherapistPracticePage()),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save your details right now. ${e.message ?? e.code}')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _logout() async {
    try {
      await firebase_auth.FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to log out right now. Please try again.')),
      );
    }
  }

  Future<void> _addStateLicensure() async {
    final value = await _promptForStateLicensure();
    if (value == null) return;
    setState(() => _stateLicensures.add(value));
  }

  Future<void> _addEducation() async {
    final entry = await _promptForEducation();
    if (entry == null) return;
    setState(() => _educations.add(entry));
  }

  List<EducationEntry> _decodeEducationEntries(Map<String, dynamic> data) {
    final results = <EducationEntry>[];
    final seen = <String>{};

    final structured = data['education_entries'];
    if (structured is Iterable) {
      for (final item in structured) {
        if (item is Map) {
          final entry = EducationEntry.fromJson(Map<String, dynamic>.from(item as Map));
          final label = entry.displayLabel;
          if (label.trim().isEmpty) continue;
          if (seen.add(label)) {
            results.add(entry);
          }
        }
      }
    }

    final legacy = data['educations'];
    if (legacy is Iterable) {
      for (final item in legacy) {
        if (item is String && item.trim().isNotEmpty) {
          final entry = EducationEntry.fromLegacyString(item);
          final label = entry.displayLabel;
          if (seen.add(label)) {
            results.add(entry);
          }
        }
      }
    }

    return results;
  }

  Future<String?> _promptForStateLicensure() async {
    final stateController = TextEditingController();
    final licenseController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? errorText;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (builderContext, setDialogState) => AlertDialog(
          title: const Text('Add State Licensure'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: stateController,
                  decoration: const InputDecoration(
                    labelText: 'State',
                    hintText: 'e.g., California, TX, New York',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.words,
                  autofocus: true,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'State is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: licenseController,
                  decoration: const InputDecoration(
                    labelText: 'License Number',
                    hintText: 'e.g., PSY12345 or 12345',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'License number is required';
                    }
                    if (value.trim().length < 3) {
                      return 'License number must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      errorText,
                      style: TextStyle(color: Theme.of(builderContext).colorScheme.error, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final state = stateController.text.trim();
                  final license = licenseController.text.trim();
                  final combined = '$state - $license';
                  Navigator.of(dialogContext).pop(combined);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<EducationEntry?> _promptForEducation() async {
    final otherQualificationController = TextEditingController();
    final otherUniversityController = TextEditingController();
    final yearController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    TextEditingController? qualificationController;
    TextEditingController? universityController;
    bool qualListenerAttached = false;
    bool uniListenerAttached = false;

    bool isOtherQualification(String? value) {
      final normalized = (value ?? '').trim().toLowerCase();
      return normalized == 'other';
    }

    bool isOtherUniversity(String? value) {
      final normalized = (value ?? '').trim().toLowerCase();
      return normalized == 'others' || normalized == 'other';
    }

    return showDialog<EducationEntry>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final showOtherQualField = isOtherQualification(qualificationController?.text);
          final showOtherUniField = isOtherUniversity(universityController?.text);
          return AlertDialog(
            title: const Text('Add Education'),
            content: Form(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Autocomplete<String>(
                    initialValue: const TextEditingValue(text: ''),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      const qualifications = [
                        'Ph.D. in Clinical Psychology',
                        'Psy.D. in Clinical Psychology',
                        'Ph.D. in Counseling Psychology',
                        'Psy.D. in Counseling Psychology',
                        'Ph.D. in School Psychology',
                        'Psy.D. in School Psychology',
                        'Master of Social Work (MSW)',
                        'Master of Arts in Counseling',
                        'Master of Science in Counseling',
                        'Master of Education in Counseling',
                        'Master of Arts in Marriage and Family Therapy',
                        'Master of Science in Marriage and Family Therapy',
                        'Master of Arts in Clinical Mental Health Counseling',
                        'Master of Science in Clinical Mental Health Counseling',
                        'Licensed Clinical Social Worker (LCSW)',
                        'Licensed Professional Counselor (LPC)',
                        'Licensed Marriage and Family Therapist (LMFT)',
                        'Licensed Mental Health Counselor (LMHC)',
                        'Licensed Clinical Professional Counselor (LCPC)',
                        'Board Certified Behavior Analyst (BCBA)',
                        'Doctor of Medicine (MD) - Psychiatry',
                        'Doctor of Osteopathic Medicine (DO) - Psychiatry',
                        'Psychiatric Nurse Practitioner (PMHNP)',
                        'Other',
                      ];
                      final query = textEditingValue.text.trim().toLowerCase();
                      if (query.isEmpty) {
                        return qualifications;
                      }
                      return qualifications.where(
                        (option) => option.toLowerCase().contains(query),
                      );
                    },
                    onSelected: (value) {
                      qualificationController?.text = value;
                      if (!isOtherQualification(value)) {
                        otherQualificationController.clear();
                      }
                      setDialogState(() {});
                    },
                    fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                      if (!qualListenerAttached) {
                        qualListenerAttached = true;
                        controller.addListener(() {
                          if (!isOtherQualification(controller.text)) {
                            otherQualificationController.clear();
                          }
                          setDialogState(() {});
                        });
                      }
                      qualificationController = controller;
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: const InputDecoration(
                          labelText: 'Qualification / Degree',
                          hintText: 'e.g., Ph.D. in Clinical Psychology',
                          border: OutlineInputBorder(),
                        ),
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Qualification is required';
                          }
                          return null;
                        },
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      final entries = options.toList();
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: entries.length > 8 ? 280 : entries.length * 48.0,
                            width: 420,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: entries.length,
                              itemBuilder: (context, index) {
                                final option = entries[index];
                                return ListTile(
                                  title: Text(option),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (showOtherQualField) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: otherQualificationController,
                      decoration: const InputDecoration(
                        labelText: 'Custom qualification',
                        hintText: 'Enter your qualification',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      validator: (value) {
                        if (isOtherQualification(qualificationController?.text) && (value == null || value.trim().isEmpty)) {
                          return 'Please specify your qualification';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  Autocomplete<String>(
                    initialValue: const TextEditingValue(text: ''),
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      final query = textEditingValue.text.trim().toLowerCase();
                      if (query.isEmpty) {
                        return ['Others', ...kUniversities.take(24)];
                      }
                      final filtered = kUniversities.where(
                        (option) => option.toLowerCase().contains(query),
                      );
                      if ('others'.contains(query)) {
                        return ['Others', ...filtered];
                      }
                      return filtered;
                    },
                    onSelected: (value) {
                      universityController?.text = value;
                      if (!isOtherUniversity(value)) {
                        otherUniversityController.clear();
                      }
                      setDialogState(() {});
                    },
                    fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                      if (!uniListenerAttached) {
                        uniListenerAttached = true;
                        controller.addListener(() {
                          if (!isOtherUniversity(controller.text)) {
                            otherUniversityController.clear();
                          }
                          setDialogState(() {});
                        });
                      }
                      universityController = controller;
                      return TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          labelText: 'University',
                          hintText: 'Search and select your institution',
                          border: const OutlineInputBorder(),
                          suffixIcon: const Icon(Icons.search),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) {
                            return 'Please choose a university';
                          }
                          if (!isOtherUniversity(text) &&
                              !kUniversities.any((option) => option.toLowerCase() == text.toLowerCase())) {
                            return 'Select from the list or choose "Others"';
                          }
                          return null;
                        },
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      final entries = options.take(20).toList();
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4,
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: entries.length > 8 ? 280 : entries.length * 48.0,
                            width: 420,
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: entries.length,
                              itemBuilder: (context, index) {
                                final option = entries[index];
                                return ListTile(
                                  title: Text(option),
                                  onTap: () => onSelected(option),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (showOtherUniField) ...[
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: otherUniversityController,
                      decoration: const InputDecoration(
                        labelText: 'Institution name',
                        hintText: 'Enter your university',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (isOtherUniversity(universityController?.text) && (value == null || value.trim().isEmpty)) {
                          return 'Please specify your university';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: yearController,
                    decoration: const InputDecoration(
                      labelText: 'Year completed',
                      hintText: 'e.g., 2018',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    buildCounter: (_, {required int currentLength, required bool isFocused, required int? maxLength}) =>
                        const SizedBox.shrink(),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) {
                        return 'Year of completion is required';
                      }
                      final parsed = int.tryParse(text);
                      final currentYear = DateTime.now().year;
                      if (parsed == null || parsed < 1900 || parsed > currentYear) {
                        return 'Enter a valid year between 1900 and $currentYear';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  final selectedQualification = qualificationController?.text.trim() ?? '';
                  final isOtherQual = isOtherQualification(selectedQualification);
                  final qualification = isOtherQual ? otherQualificationController.text.trim() : selectedQualification;
                  
                  final selectedUniversity = universityController?.text.trim() ?? '';
                  final isOtherUni = isOtherUniversity(selectedUniversity);
                  final institution = isOtherUni ? otherUniversityController.text.trim() : selectedUniversity;
                  final yearText = yearController.text.trim();
                  final year = yearText.isEmpty ? null : int.tryParse(yearText);

                  final entry = EducationEntry(
                    qualification: qualification,
                    university: isOtherUni ? 'Others' : selectedUniversity,
                    institutionOverride: isOtherUni ? institution : null,
                    yearCompleted: year,
                  );
                  Navigator.of(dialogContext).pop(entry);
                },
                child: const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickAndUpload(String type) async {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      if (type == 'profile') _isUploadingProfile = true;
      if (type == 'qualification') _isUploadingQualification = true;
      if (type == 'id') _isUploadingId = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: type == 'qualification' ? FileType.any : FileType.image,
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        final name = file.name;

        if (bytes != null) {
          final ref = FirebaseStorage.instance
              .ref()
              .child('therapists/${user.uid}/uploads/${DateTime.now().millisecondsSinceEpoch}_$name');
          
          final metadata = SettableMetadata(contentType: type == 'qualification' ? null : 'image/jpeg');
          
          final task = await ref.putData(bytes, metadata);
          final url = await task.ref.getDownloadURL();

          setState(() {
            if (type == 'profile') _profilePhotoUrl = url;
            if (type == 'qualification') _qualificationUrl = url;
            if (type == 'id') _idPhotoUrl = url;
          });
        }
      }
    } catch (e) {
      debugPrint('Upload error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          if (type == 'profile') _isUploadingProfile = false;
          if (type == 'qualification') _isUploadingQualification = false;
          if (type == 'id') _isUploadingId = false;
        });
      }
    }
  }

  Widget _buildUploadSection({
    required String title,
    required String? url,
    required bool isLoading,
    required VoidCallback onUpload,
    required IconData icon,
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasFile = url != null && url.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withValues(alpha: 0.6))),
        ],
        const SizedBox(height: 8),
        InkWell(
          onTap: isLoading ? null : onUpload,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasFile ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.3),
                width: hasFile ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: hasFile ? colorScheme.primary.withValues(alpha: 0.1) : colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
                        )
                      : Icon(
                          hasFile ? Icons.check : icon,
                          color: hasFile ? colorScheme.primary : colorScheme.onSurfaceVariant,
                          size: 20,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasFile ? 'File Uploaded' : 'Tap to upload',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: hasFile ? FontWeight.w600 : FontWeight.w500,
                          color: hasFile ? colorScheme.primary : colorScheme.onSurface,
                        ),
                      ),
                      if (hasFile)
                        Text(
                          'Click to replace',
                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                if (hasFile && (title.contains('Photo') || title.contains('ID'))) ...[
                   ClipRRect(
                     borderRadius: BorderRadius.circular(4),
                     child: Image.network(url, width: 40, height: 40, fit: BoxFit.cover),
                   ),
                ]
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final borderColor = Colors.grey.withValues(alpha: 0.3);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
        ),
      ),
    );
  }

  Widget _buildChipList({
    required List<String> values,
    required void Function(String value) onRemove,
  }) {
    if (values.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final value in values)
          InputChip(
            label: Text(value),
            onDeleted: () => onRemove(value),
            deleteIcon: const Icon(Icons.close, size: 18),
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
      ],
    );
  }

  Widget _buildEducationList() {
    if (_educations.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
        ),
        child: Text(
          'Add your academic qualifications so patients can see your expertise at a glance.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < _educations.length; i++) ...[
          _buildEducationCard(_educations[i]),
          if (i != _educations.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildEducationCard(EducationEntry entry) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final institution = entry.resolvedInstitution;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.primary.withOpacity(0.12),
              child: Icon(Icons.school_outlined, color: colorScheme.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.qualification.trim().isNotEmpty ? entry.qualification.trim() : institution,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (institution.isNotEmpty && entry.qualification.trim() != institution) ...[
                    const SizedBox(height: 4),
                    Text(
                      institution,
                      style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                    ),
                  ],
                  if (entry.yearCompleted != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'Class of ${entry.yearCompleted}',
                        style: theme.textTheme.labelMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ]
                ],
              ),
            ),
            IconButton(
              onPressed: () => _removeEducation(entry),
              icon: const Icon(Icons.delete_outline),
              color: colorScheme.error,
              tooltip: 'Remove',
            ),
          ],
        ),
      ),
    );
  }

  void _removeStateLicensure(String value) {
    setState(() => _stateLicensures.remove(value));
  }

  void _removeEducation(EducationEntry value) {
    setState(() => _educations.remove(value));
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Therapii',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _logout,
                        icon: const Icon(Icons.logout, size: 18),
                        label: const Text('Logout'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Contact and Licensure Information',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 24),
                  _buildInputField(controller: _nameCtrl, hintText: 'Full Name'),
                  const SizedBox(height: 16),
                  _buildInputField(controller: _practiceCtrl, hintText: 'Practice / Office Name'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildInputField(controller: _cityCtrl, hintText: 'City')),
                      const SizedBox(width: 12),
                      SizedBox(width: 120, child: _buildInputField(controller: _stateCtrl, hintText: 'State')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(controller: _zipCtrl, hintText: 'Zip Code', keyboardType: TextInputType.number),
                  const SizedBox(height: 16),
                  _buildInputField(controller: _emailCtrl, hintText: 'Email Address', keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  _buildInputField(controller: _phoneCtrl, hintText: 'Phone Number', keyboardType: TextInputType.phone),
                  const SizedBox(height: 24),
                  _buildUploadSection(
                    title: 'Profile Photo',
                    subtitle: 'Upload a clear photo of yourself.',
                    url: _profilePhotoUrl,
                    isLoading: _isUploadingProfile,
                    onUpload: () => _pickAndUpload('profile'),
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                  _buildUploadSection(
                    title: 'Qualification Document',
                    subtitle: 'Upload a copy of your degree or certificate.',
                    url: _qualificationUrl,
                    isLoading: _isUploadingQualification,
                    onUpload: () => _pickAndUpload('qualification'),
                    icon: Icons.school_outlined,
                  ),
                  const SizedBox(height: 16),
                  _buildUploadSection(
                    title: 'Government ID',
                    subtitle: 'Upload a photo of your ID (Passport, License, etc).',
                    url: _idPhotoUrl,
                    isLoading: _isUploadingId,
                    onUpload: () => _pickAndUpload('id'),
                    icon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'State Licensure',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        onPressed: _addStateLicensure,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildChipList(
                    values: _stateLicensures,
                    onRemove: _removeStateLicensure,
                  ),
                  GestureDetector(
                    onTap: _addStateLicensure,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Add another State Licensure',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Education',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        onPressed: _addEducation,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildEducationList(),
                  GestureDetector(
                    onTap: _addEducation,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Add another Education',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      SizedBox(
                        width: 160,
                        child: PrimaryButton(
                          label: 'Continue',
                          onPressed: _submitting ? null : _continue,
                          isLoading: _submitting,
                          uppercase: false,
                        ),
                      ),
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: Text(
                          'Go Back',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: colorScheme.primary,
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
