import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:therapii/auth/firebase_auth_manager.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final _apiKeyController = TextEditingController();
  final _emailFromController = TextEditingController();
  final _emailFromNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  bool _obscureKey = true;
  String? _currentKey;
  String? _currentEmailFrom;
  String? _currentEmailFromName;
  String? _lastUpdatedBy;
  DateTime? _lastUpdatedAt;
  String? _emailLastUpdatedBy;
  DateTime? _emailLastUpdatedAt;
  bool _emailEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _emailFromController.dispose();
    _emailFromNameController.dispose();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    setState(() => _loading = true);
    try {
      final openaiDoc = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('openai_config')
          .get();

      if (openaiDoc.exists && mounted) {
        final data = openaiDoc.data();
        _currentKey = data?['api_key'] as String?;
        _lastUpdatedBy = data?['updated_by'] as String?;
        final timestamp = data?['updated_at'] as Timestamp?;
        _lastUpdatedAt = timestamp?.toDate();
        
        if (_currentKey != null) {
          _apiKeyController.text = _currentKey!;
        }
      }

      final emailDoc = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('email_config')
          .get();

      if (emailDoc.exists && mounted) {
        final data = emailDoc.data();
        _currentEmailFrom = data?['from_email'] as String?;
        _currentEmailFromName = data?['from_name'] as String?;
        _emailEnabled = (data?['enabled'] as bool?) ?? true;
        _emailLastUpdatedBy = data?['updated_by'] as String?;
        final timestamp = data?['updated_at'] as Timestamp?;
        _emailLastUpdatedAt = timestamp?.toDate();
        
        if (_currentEmailFrom != null) {
          _emailFromController.text = _currentEmailFrom!;
        }
        if (_currentEmailFromName != null) {
          _emailFromNameController.text = _currentEmailFromName!;
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to load configuration: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _saveApiKey() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final user = FirebaseAuthManager().currentUser;
      if (user == null) {
        _showError('You must be signed in to save settings.');
        return;
      }

      final apiKey = _apiKeyController.text.trim();
      await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('openai_config')
          .set({
        'api_key': apiKey,
        'updated_by': user.email ?? user.uid,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSuccess('OpenAI API key saved successfully!');
        await _loadApiKey();
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to save API key: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteApiKey() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete API Key'),
        content: const Text(
          'Are you sure you want to delete the OpenAI API key? This will disable the AI companion throughout the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('openai_config')
          .delete();

      if (mounted) {
        _apiKeyController.clear();
        _currentKey = null;
        _lastUpdatedBy = null;
        _lastUpdatedAt = null;
        _showSuccess('API key deleted successfully.');
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to delete API key: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _saveEmailConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final user = FirebaseAuthManager().currentUser;
      if (user == null) {
        _showError('You must be signed in to save settings.');
        return;
      }

      final fromEmail = _emailFromController.text.trim();
      final fromName = _emailFromNameController.text.trim();
      await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('email_config')
          .set({
        'from_email': fromEmail,
        'from_name': fromName,
        'enabled': _emailEnabled,
        'updated_by': user.email ?? user.uid,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSuccess('Email configuration saved successfully!');
        await _loadApiKey();
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to save email configuration: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteEmailConfig() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Email Config'),
        content: const Text(
          'Are you sure you want to delete the email configuration? This will disable email notifications.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('email_config')
          .delete();

      if (mounted) {
        _emailFromController.clear();
        _emailFromNameController.clear();
        _currentEmailFrom = null;
        _currentEmailFromName = null;
        _emailLastUpdatedBy = null;
        _emailLastUpdatedAt = null;
        _showSuccess('Email configuration deleted successfully.');
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to delete email configuration: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Admin Settings'),
        centerTitle: true,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: scheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.admin_panel_settings,
                            color: scheme.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'OpenAI Configuration',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Configure the OpenAI API key for the AI companion chatbot. Changes take effect immediately across the entire app.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'API Key',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _apiKeyController,
                      obscureText: _obscureKey,
                      decoration: InputDecoration(
                        hintText: 'sk-proj-...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                _obscureKey ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() => _obscureKey = !_obscureKey);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.content_copy),
                              onPressed: () {
                                final key = _apiKeyController.text;
                                if (key.isNotEmpty) {
                                  Clipboard.setData(ClipboardData(text: key));
                                  _showSuccess('API key copied to clipboard');
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter an API key';
                        }
                        if (!value.startsWith('sk-')) {
                          return 'API key should start with "sk-"';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_lastUpdatedBy != null || _lastUpdatedAt != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Last updated${_lastUpdatedBy != null ? " by $_lastUpdatedBy" : ""}${_lastUpdatedAt != null ? " on ${_formatDate(_lastUpdatedAt!)}" : ""}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _saveApiKey,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(_saving ? 'Saving...' : 'Save API Key'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: scheme.primary,
                              foregroundColor: scheme.onPrimary,
                            ),
                          ),
                        ),
                        if (_currentKey != null) ...[
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: _saving ? null : _deleteApiKey,
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.red,
                            tooltip: 'Delete API Key',
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.help_outline,
                                color: scheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'How to get an OpenAI API Key',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildStep('1', 'Visit platform.openai.com'),
                          _buildStep('2', 'Sign in or create an account'),
                          _buildStep('3', 'Navigate to API Keys section'),
                          _buildStep('4', 'Click "Create new secret key"'),
                          _buildStep('5', 'Copy and paste the key above'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: scheme.secondary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.email_outlined,
                            color: scheme.secondary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Email Configuration',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Configure email settings for invitation notifications via Firebase Extension + Resend.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurface.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'From Email Address',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailFromController,
                      decoration: InputDecoration(
                        hintText: 'noreply@yourdomain.com',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) {
                          return 'Please enter a sender email';
                        }
                        if (!v.contains('@') || v.startsWith('@') || v.endsWith('@')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'From Name',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailFromNameController,
                      decoration: InputDecoration(
                        hintText: 'Therapii',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_emailLastUpdatedBy != null || _emailLastUpdatedAt != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: scheme.onSurface.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Last updated${_emailLastUpdatedBy != null ? " by $_emailLastUpdatedBy" : ""}${_emailLastUpdatedAt != null ? " on ${_formatDate(_emailLastUpdatedAt!)}" : ""}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable email delivery'),
                      value: _emailEnabled,
                      onChanged: (v) => setState(() => _emailEnabled = v),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _saveEmailConfig,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(_saving ? 'Saving...' : 'Save Email Config'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: scheme.secondary,
                              foregroundColor: scheme.onSecondary,
                            ),
                          ),
                        ),
                        if (_currentEmailFrom != null) ...[
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: _saving ? null : _deleteEmailConfig,
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.red,
                            tooltip: 'Delete Email Config',
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.help_outline,
                                color: scheme.secondary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Setup Firebase Extension + Resend',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildStep('1', 'Sign up at resend.com and create an API key'),
                          _buildStep('2', 'Go to Firebase Console > Extensions'),
                          _buildStep('3', 'Install "Trigger Email from Firestore"'),
                          _buildStep('4', 'Configure SMTP: Host=smtp.resend.com, Port=465'),
                          _buildStep('5', 'Set Username=resend, Password=your_api_key'),
                          _buildStep('6', 'Set Collection path to "mail"'),
                          _buildStep('7', 'Verify your domain in Resend for production'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStep(String number, String text) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) {
          return 'just now';
        }
        return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
      }
      return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
