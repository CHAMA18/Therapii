import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:therapii/auth/firebase_auth_manager.dart';
import 'package:therapii/models/user.dart' as app_models;
import 'package:therapii/services/user_service.dart';
import 'package:therapii/theme.dart';
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
        title: const Text('Edit Profile'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Header(
              emailMasked: emailMasked,
              displayName: _profile?.fullName,
              avatarBytes: _avatarPreviewBytes,
              avatarUrl: _avatarUrl,
              isLoading: _loadingProfile,
              isUploading: _uploadingAvatar,
              onPickAvatar: (_loadingProfile || _uploadingAvatar) ? null : _pickAvatar,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
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
                        ),
                        validator: (v) {
                          final value = (v ?? '').trim();
                          if (value.isEmpty) return 'Enter a new email';
                          if (!value.contains('@') || !value.contains('.')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _currentPassForEmailCtrl,
                        obscureText: !_showCurrentPassForEmail,
                        decoration: InputDecoration(
                          labelText: 'Current password (for verification)',
                          prefixIcon: Icon(Icons.lock_outline, color: scheme.primary),
                          filled: true,
                          suffixIcon: IconButton(
                            icon: AnimatedRotation(
                              duration: const Duration(milliseconds: 180),
                              turns: _showCurrentPassForEmail ? 0.25 : 0,
                              child: Icon(_showCurrentPassForEmail ? Icons.visibility_off : Icons.visibility, color: scheme.primary),
                            ),
                            onPressed: () => setState(() => _showCurrentPassForEmail = !_showCurrentPassForEmail),
                          ),
                        ),
                        validator: (v) => (v ?? '').length < 6 ? 'Enter your current password' : null,
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: PrimaryButton(
                              label: 'Send verification',
                              leadingIcon: Icons.mark_email_read_outlined,
                              isLoading: _emailUpdating,
                              onPressed: _emailUpdating ? null : _handleUpdateEmail,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                           'We’ll email a verification link to your new address. After you verify, your email will update automatically.',
                          style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 16)),
          // Password section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
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
                          suffixIcon: IconButton(
                            icon: AnimatedRotation(
                              duration: const Duration(milliseconds: 180),
                              turns: _showCurrentPass ? 0.25 : 0,
                              child: Icon(_showCurrentPass ? Icons.visibility_off : Icons.visibility, color: scheme.primary),
                            ),
                            onPressed: () => setState(() => _showCurrentPass = !_showCurrentPass),
                          ),
                        ),
                        validator: (v) => (v ?? '').length < 6 ? 'Enter your current password' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _newPassCtrl,
                        obscureText: !_showNewPass,
                        decoration: InputDecoration(
                          labelText: 'New password',
                          prefixIcon: Icon(Icons.lock, color: scheme.primary),
                          filled: true,
                          suffixIcon: IconButton(
                            icon: AnimatedRotation(
                              duration: const Duration(milliseconds: 180),
                              turns: _showNewPass ? 0.25 : 0,
                              child: Icon(_showNewPass ? Icons.visibility_off : Icons.visibility, color: scheme.primary),
                            ),
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
                        const SizedBox(height: 8),
                        _PasswordStrengthBar(value: _passStrength, label: _passLabel),
                        const SizedBox(height: 10),
                      ] else
                        const SizedBox(height: 10),
                      TextFormField(
                        controller: _confirmPassCtrl,
                        obscureText: !_showConfirmPass,
                        decoration: InputDecoration(
                          labelText: 'Confirm new password',
                          prefixIcon: Icon(Icons.lock, color: scheme.primary),
                          filled: true,
                          suffixIcon: IconButton(
                            icon: AnimatedRotation(
                              duration: const Duration(milliseconds: 180),
                              turns: _showConfirmPass ? 0.25 : 0,
                              child: Icon(_showConfirmPass ? Icons.visibility_off : Icons.visibility, color: scheme.primary),
                            ),
                            onPressed: () => setState(() => _showConfirmPass = !_showConfirmPass),
                          ),
                        ),
                        validator: (v) {
                          if (v != _newPassCtrl.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        label: 'Update password',
                        leadingIcon: Icons.check_circle_outline,
                        isLoading: _changingPassword,
                        onPressed: _changingPassword ? null : _handleChangePassword,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
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

// Header with gradient and curved bottom
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
    final gradient = AppGradients.primaryFor(theme.brightness);
    final scheme = theme.colorScheme;
    final hasEmail = emailMasked.trim().isNotEmpty;
    final trimmedName = displayName?.trim();
    final headerTitle = (trimmedName != null && trimmedName.isNotEmpty) ? trimmedName : 'Edit Profile';

    final hasBytes = avatarBytes != null && avatarBytes!.isNotEmpty;
    final hasUrl = (avatarUrl ?? '').isNotEmpty;
    final ImageProvider<Object>? imageProvider = hasBytes
        ? MemoryImage(avatarBytes!)
        : (hasUrl ? NetworkImage(avatarUrl!) : null);
    final showSpinner = isLoading && imageProvider == null && !hasBytes;

    final baseAvatar = CircleAvatar(
      radius: 36,
      backgroundColor: scheme.onPrimary.withValues(alpha: 0.18),
      backgroundImage: showSpinner ? null : imageProvider,
      child: showSpinner
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(scheme.onPrimary),
              ),
            )
          : (imageProvider == null
              ? Icon(Icons.person, color: scheme.onPrimary, size: 36)
              : null),
    );

    Widget avatar = SizedBox(
      width: 72,
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: baseAvatar),
          if (onPickAvatar != null)
            Positioned(
              bottom: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: scheme.onPrimary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: scheme.onPrimary.withValues(alpha: 0.45),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.edit, size: 16, color: scheme.primary),
              ),
            ),
          if (isUploading)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.onPrimary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
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

    final helperKey = ValueKey('${isUploading}_helper');

    return Stack(
      children: [
        Container(
          height: 190,
          decoration: BoxDecoration(
            gradient: gradient,
          ),
        ),
        ClipPath(
          clipper: _BottomCurveClipper(),
          child: Container(
            height: 190,
            decoration: BoxDecoration(
              gradient: gradient,
            ),
          ),
        ),
        Container(
          height: 190,
          padding: const EdgeInsets.fromLTRB(20, 96, 20, 24),
          alignment: Alignment.bottomLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              avatar,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headerTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: scheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Update your profile photo, email, and password',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onPrimary.withValues(alpha: 0.9),
                      ),
                    ),
                    if (onPickAvatar != null)
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          isUploading ? 'Uploading photo...' : 'Tap the photo to change it',
                          key: helperKey,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onPrimary.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    if (hasEmail) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Signed in as $emailMasked',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimary.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BottomCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height - 36);
    path.quadraticBezierTo(size.width * 0.25, size.height, size.width * 0.5, size.height);
    path.quadraticBezierTo(size.width * 0.75, size.height, size.width, size.height - 36);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// Section card with subtle glass effect
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: scheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
