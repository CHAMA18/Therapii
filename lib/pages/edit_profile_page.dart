import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:therapii/auth/firebase_auth_manager.dart';
import 'package:therapii/models/user.dart' as app_models;
import 'package:therapii/services/user_service.dart';
import 'package:therapii/widgets/primary_button.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _userService = UserService();

  app_models.User? _profile;
  Uint8List? _avatarPreviewBytes;
  String? _avatarUrl;
  bool _loadingProfile = true;
  bool _uploadingAvatar = false;

  // Email form
  final _emailFormKey = GlobalKey<FormState>();
  final _newEmailCtrl = TextEditingController();
  final _currentPassForEmailCtrl = TextEditingController();
  bool _emailUpdating = false;
  bool _showCurrentPassForEmail = false;

  // Password form
  final _passwordFormKey = GlobalKey<FormState>();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _changingPassword = false;
  bool _showCurrentPass = false;
  bool _showNewPass = false;
  bool _showConfirmPass = false;

  // Password strength
  double _passStrength = 0.0; // 0..1
  String _passLabel = '';

  @override
  void initState() {
    super.initState();
    _newPassCtrl.addListener(_evaluatePasswordStrength);
    _loadProfile();
  }

  @override
  void dispose() {
    _newEmailCtrl.dispose();
    _currentPassForEmailCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final current = firebase_auth.FirebaseAuth.instance.currentUser;
    if (current == null) {
      if (mounted) {
        setState(() => _loadingProfile = false);
      }
      return;
    }

    try {
      final user = await _userService.getUser(current.uid);
      if (!mounted) return;
      setState(() {
        _profile = user;
        _avatarUrl = user?.avatarUrl;
        _avatarPreviewBytes = null;
        _loadingProfile = false;
      });
    } catch (e, st) {
      debugPrint('Failed to load profile: $e\n$st');
      if (!mounted) return;
      setState(() => _loadingProfile = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load profile details.')),
        );
      });
    }
  }

  String _maskEmail(String? email) {
    if (email == null || email.isEmpty) return '';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    final domain = parts[1];
    final maskedLocal = local.length <= 2
        ? '${local[0]}*'
        : '${local.substring(0, 2)}***';
    return '$maskedLocal@$domain';
  }

  Future<void> _handleUpdateEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() => _emailUpdating = true);
    try {
      final auth = FirebaseAuthManager();
      // Reauthenticate
      final ok = await auth.reauthenticateWithPassword(
        context: context,
        currentPassword: _currentPassForEmailCtrl.text.trim(),
      );
      if (!ok) return;

      await auth.updateEmail(email: _newEmailCtrl.text.trim(), context: context);
      if (!mounted) return;
      // Suggest the user verify email, then offer a refresh to sync.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Check your inbox to verify the new email.'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _emailUpdating = false);
    }
  }
  

  Future<void> _pickAvatar() async {
    final current = firebase_auth.FirebaseAuth.instance.currentUser;
    if (current == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in again to update your profile photo.')),
      );
      return;
    }
    if (_uploadingAvatar) return;

    final previousBytes = _avatarPreviewBytes;
    final previousUrl = _avatarUrl;

    try {
      const typeGroup = XTypeGroup(
        label: 'Images',
        extensions: ['png', 'jpg', 'jpeg', 'gif', 'webp'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That file looked empty. Please choose another image.')),
        );
        return;
      }

      const maxBytes = 5 * 1024 * 1024;
      if (bytes.length > maxBytes) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an image under 5MB.')),
        );
        return;
      }

      if (mounted) {
        setState(() {
          _avatarPreviewBytes = bytes;
          _uploadingAvatar = true;
        });
      }

      final downloadUrl = await _uploadAvatar(
        userId: current.uid,
        fileName: file.name,
        bytes: bytes,
      );

      await _userService.updateProfile(userId: current.uid, avatarUrl: downloadUrl);
      await current.updatePhotoURL(downloadUrl);

      if (!mounted) return;
      setState(() {
        _avatarUrl = downloadUrl;
        _profile = _profile?.copyWith(avatarUrl: downloadUrl);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated.')),
      );
    } catch (e, st) {
      debugPrint('Profile photo update failed: $e\n$st');
      if (!mounted) return;
      setState(() {
        _avatarPreviewBytes = previousBytes;
        _avatarUrl = previousUrl;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update profile photo. Please try again.')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
    }
  }

  Future<String> _uploadAvatar({
    required String userId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final ext = _extensionForStorage(fileName);
    final metadata = SettableMetadata(contentType: _contentTypeForExtension(ext));
    final ref = FirebaseStorage.instance.ref('user_avatars/$userId/profile.$ext');
    await ref.putData(bytes, metadata);
    return ref.getDownloadURL();
  }

  String _extensionForStorage(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    final rawExt = dotIndex == -1 ? '' : fileName.substring(dotIndex + 1).toLowerCase();
    switch (rawExt) {
      case 'jpg':
      case 'jpeg':
        return 'jpg';
      case 'png':
      case 'gif':
      case 'webp':
        return rawExt;
      default:
        return 'png';
    }
  }

  String _contentTypeForExtension(String ext) {
    switch (ext) {
      case 'jpg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _handleChangePassword() async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() => _changingPassword = true);
    try {
      final auth = FirebaseAuthManager();
      final ok = await auth.reauthenticateWithPassword(
        context: context,
        currentPassword: _currentPassCtrl.text.trim(),
      );
      if (!ok) return;
      await auth.updatePassword(
        context: context,
        newPassword: _newPassCtrl.text.trim(),
      );
      if (!mounted) return;
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
    } finally {
      if (mounted) setState(() => _changingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    final emailMasked = _maskEmail(user?.email);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        child: Column(
          children: [
            _Header(
              emailMasked: emailMasked,
              displayName: _profile?.fullName,
              avatarBytes: _avatarPreviewBytes,
              avatarUrl: _avatarUrl,
              isLoading: _loadingProfile,
              isUploading: _uploadingAvatar,
              onPickAvatar: (_loadingProfile || _uploadingAvatar) ? null : _pickAvatar,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: _SectionCard(
                icon: Icons.alternate_email,
                title: 'Change email / username',
                subtitle: 'Current: $emailMasked',
                child: Form(
                  key: _emailFormKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _newEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'New email',
                          prefixIcon: Icon(Icons.email_outlined, color: scheme.primary),
                          filled: true,
                          fillColor: const Color(0xFFF0F4F8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.primary, width: 1.5)),
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'Enter a new email';
                          if (!value.contains('@') || !value.contains('.')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _currentPassForEmailCtrl,
                        obscureText: !_showCurrentPassForEmail,
                        decoration: InputDecoration(
                          labelText: 'Current password (for verification)',
                          prefixIcon: Icon(Icons.lock_outline, color: scheme.primary),
                          filled: true,
                          fillColor: const Color(0xFFF0F4F8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.primary, width: 1.5)),
                          suffixIcon: IconButton(
                            icon: Icon(_showCurrentPassForEmail ? Icons.visibility_off : Icons.visibility, color: scheme.primary),
                            onPressed: () => setState(() => _showCurrentPassForEmail = !_showCurrentPassForEmail),
                          ),
                        ),
                        validator: (v) => (v ?? '').length < 6 ? 'Enter your current password' : null,
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          label: 'Send verification',
                          leadingIcon: Icons.mark_email_read_outlined,
                          isLoading: _emailUpdating,
                          onPressed: _emailUpdating ? null : _handleUpdateEmail,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "We'll email a verification link to your new address. After you verify, your email will update automatically.",
                        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Password section
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: _SectionCard(
                icon: Icons.password,
                title: 'Change password',
                child: Form(
                  key: _passwordFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _currentPassCtrl,
                        obscureText: !_showCurrentPass,
                        decoration: InputDecoration(
                          labelText: 'Current password',
                          prefixIcon: Icon(Icons.lock_outline, color: scheme.primary),
                          filled: true,
                          fillColor: const Color(0xFFF0F4F8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.primary, width: 1.5)),
                          suffixIcon: IconButton(
                            icon: Icon(_showCurrentPass ? Icons.visibility_off : Icons.visibility, color: scheme.primary),
                            onPressed: () => setState(() => _showCurrentPass = !_showCurrentPass),
                          ),
                        ),
                        validator: (v) => (v ?? '').length < 6 ? 'Enter your current password' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _newPassCtrl,
                        obscureText: !_showNewPass,
                        decoration: InputDecoration(
                          labelText: 'New password',
                          prefixIcon: Icon(Icons.lock, color: scheme.primary),
                          filled: true,
                          fillColor: const Color(0xFFF0F4F8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.primary, width: 1.5)),
                          suffixIcon: IconButton(
                            icon: Icon(_showNewPass ? Icons.visibility_off : Icons.visibility, color: scheme.primary),
                            onPressed: () => setState(() => _showNewPass = !_showNewPass),
                          ),
                        ),
                        validator: (v) {
                          final value = (v ?? '');
                          if (value.length < 6) return 'Use at least 6 characters';
                          return null;
                        },
                      ),
                      if (_newPassCtrl.text.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _PasswordStrengthBar(value: _passStrength, label: _passLabel),
                        const SizedBox(height: 14),
                      ] else
                        const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmPassCtrl,
                        obscureText: !_showConfirmPass,
                        decoration: InputDecoration(
                          labelText: 'Confirm new password',
                          prefixIcon: Icon(Icons.lock, color: scheme.primary),
                          filled: true,
                          fillColor: const Color(0xFFF0F4F8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: scheme.primary, width: 1.5)),
                          suffixIcon: IconButton(
                            icon: Icon(_showConfirmPass ? Icons.visibility_off : Icons.visibility, color: scheme.primary),
                            onPressed: () => setState(() => _showConfirmPass = !_showConfirmPass),
                          ),
                        ),
                        validator: (v) {
                          if (v != _newPassCtrl.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: PrimaryButton(
                          label: 'Update password',
                          leadingIcon: Icons.check_circle_outline,
                          isLoading: _changingPassword,
                          onPressed: _changingPassword ? null : _handleChangePassword,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _evaluatePasswordStrength() {
    final v = _newPassCtrl.text;
    double score = 0;
    if (v.isEmpty) {
      setState(() {
        _passStrength = 0;
        _passLabel = '';
      });
      return;
    }
    final length = v.length;
    final hasLower = v.contains(RegExp(r'[a-z]'));
    final hasUpper = v.contains(RegExp(r'[A-Z]'));
    final hasDigit = v.contains(RegExp(r'[0-9]'));
    final hasSpecial = v.contains(RegExp(r'[^A-Za-z0-9]'));
    score += (length >= 6 ? 0.2 : length / 30);
    score += hasLower ? 0.2 : 0;
    score += hasUpper ? 0.2 : 0;
    score += hasDigit ? 0.2 : 0;
    score += hasSpecial ? 0.2 : 0;
    score = score.clamp(0.0, 1.0);
    String label;
    if (score < 0.4) {
      label = 'Weak';
    } else if (score < 0.7) {
      label = 'Medium';
    } else {
      label = 'Strong';
    }
    setState(() {
      _passStrength = score;
      _passLabel = label;
    });
  }
}

// Premium header with world-class design
class _Header extends StatelessWidget {
  final String emailMasked;
  final String? displayName;
  final Uint8List? avatarBytes;
  final String? avatarUrl;
  final bool isLoading;
  final bool isUploading;
  final VoidCallback? onPickAvatar;

  const _Header({
    required this.emailMasked,
    this.displayName,
    this.avatarBytes,
    this.avatarUrl,
    this.isLoading = false,
    this.isUploading = false,
    this.onPickAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasEmail = emailMasked.trim().isNotEmpty;
    final trimmedName = displayName?.trim();
    final headerTitle = (trimmedName != null && trimmedName.isNotEmpty) ? trimmedName : 'Your Profile';

    final hasBytes = avatarBytes != null && avatarBytes!.isNotEmpty;
    final hasUrl = (avatarUrl ?? '').isNotEmpty;
    final ImageProvider<Object>? imageProvider = hasBytes
        ? MemoryImage(avatarBytes!)
        : (hasUrl ? NetworkImage(avatarUrl!) : null);
    final showSpinner = isLoading && imageProvider == null && !hasBytes;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0066FF),
            Color(0xFF2E86FF),
            Color(0xFF4DA3FF),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(36),
          bottomRight: Radius.circular(36),
        ),
      ),
      child: Stack(
        children: [
          // Frosted glass orbs for depth
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: -50,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            top: 60,
            left: 30,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          // Main content
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Avatar with glowing ring
                  _AvatarWithGlow(
                    imageProvider: imageProvider,
                    showSpinner: showSpinner,
                    isUploading: isUploading,
                    onPickAvatar: onPickAvatar,
                  ),
                  const SizedBox(height: 20),
                  // Name with premium styling
                  Text(
                    headerTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Update your profile photo, email, and password',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                      height: 1.4,
                    ),
                  ),
                  if (hasEmail) ...[
                    const SizedBox(height: 16),
                    // Frosted glass email badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.verified_user_rounded,
                              size: 14,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Signed in as $emailMasked',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarWithGlow extends StatelessWidget {
  final ImageProvider<Object>? imageProvider;
  final bool showSpinner;
  final bool isUploading;
  final VoidCallback? onPickAvatar;

  const _AvatarWithGlow({
    this.imageProvider,
    required this.showSpinner,
    required this.isUploading,
    this.onPickAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget avatar = Container(
      width: 110,
      height: 110,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.35),
            Colors.white.withValues(alpha: 0.15),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.white.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: -5,
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.3),
              blurRadius: 12,
            ),
          ],
        ),
        child: Stack(
          children: [
            CircleAvatar(
              radius: 51,
              backgroundColor: scheme.primary.withValues(alpha: 0.1),
              backgroundImage: showSpinner ? null : imageProvider,
              child: showSpinner
                  ? SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                      ),
                    )
                  : (imageProvider == null
                      ? Icon(Icons.person_rounded, color: scheme.primary, size: 48)
                      : null),
            ),
            // Camera button
            if (onPickAvatar != null)
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [scheme.primary, const Color(0xFF2E86FF)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: const Icon(Icons.camera_alt_rounded, size: 16, color: Colors.white),
                ),
              ),
            // Upload overlay
            if (isUploading)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    if (onPickAvatar != null) {
      avatar = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isUploading ? null : onPickAvatar,
          customBorder: const CircleBorder(),
          child: avatar,
        ),
      );
    }

    return avatar;
  }
}

// Section card with clean modern styling
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  const _SectionCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: scheme.primary, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

class _PasswordStrengthBar extends StatelessWidget {
  final double value; // 0..1
  final String label;
  const _PasswordStrengthBar({required this.value, required this.label});

  Color _color(ColorScheme scheme) {
    if (value < 0.4) return scheme.error; // weak
    if (value < 0.7) return scheme.primary; // medium
    return scheme.tertiary; // strong
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = _color(scheme);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: value == 0 ? null : value,
            backgroundColor: scheme.outline.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 6),
        if (label.isNotEmpty)
          Text('Strength: $label', style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
      ],
    );
  }
}
