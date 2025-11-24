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
  final _sendgridApiKeyController = TextEditingController();
  final _sendgridApiKeyIdController = TextEditingController();
  final _sendgridFromEmailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  bool _obscureKey = true;
  bool _obscureSendgridKey = true;
  String? _currentKey;
  String? _currentSendgridApiKey;
  String? _currentSendgridApiKeyId;
  String? _currentSendgridFromEmail;
  String? _lastUpdatedBy;
  DateTime? _lastUpdatedAt;
  String? _sendgridLastUpdatedBy;
  DateTime? _sendgridLastUpdatedAt;
  bool _sendgridEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _sendgridApiKeyController.dispose();
    _sendgridApiKeyIdController.dispose();
    _sendgridFromEmailController.dispose();
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

      final sendgridDoc = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('sendgrid_config')
          .get();

      if (sendgridDoc.exists && mounted) {
        final data = sendgridDoc.data();
        _currentSendgridApiKey = data?['api_key'] as String?;
        _currentSendgridApiKeyId = data?['api_key_id'] as String?;
        _currentSendgridFromEmail = data?['from_email'] as String?;
        _sendgridEnabled = (data?['enabled'] as bool?) ?? true;
        _sendgridLastUpdatedBy = data?['updated_by'] as String?;
        final timestamp = data?['updated_at'] as Timestamp?;
        _sendgridLastUpdatedAt = timestamp?.toDate();
        
        if (_currentSendgridApiKey != null) {
          _sendgridApiKeyController.text = _currentSendgridApiKey!;
        }
        if (_currentSendgridApiKeyId != null) {
          _sendgridApiKeyIdController.text = _currentSendgridApiKeyId!;
        }
        if (_currentSendgridFromEmail != null) {
          _sendgridFromEmailController.text = _currentSendgridFromEmail!;
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

  Future<void> _saveSendgridConfig() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final user = FirebaseAuthManager().currentUser;
      if (user == null) {
        _showError('You must be signed in to save settings.');
        return;
      }

      final apiKey = _sendgridApiKeyController.text.trim();
      final apiKeyId = _sendgridApiKeyIdController.text.trim();
      final fromEmail = _sendgridFromEmailController.text.trim();
      await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('sendgrid_config')
          .set({
        'api_key': apiKey,
        'api_key_id': apiKeyId,
        'from_email': fromEmail,
        'enabled': _sendgridEnabled,
        'updated_by': user.email ?? user.uid,
        'updated_at': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showSuccess('SendGrid configuration saved successfully!');
        await _loadApiKey();
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to save SendGrid configuration: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _deleteSendgridConfig() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete SendGrid Config'),
        content: const Text(
          'Are you sure you want to delete the SendGrid configuration? This will disable email notifications.',
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
          .doc('sendgrid_config')
          .delete();

      if (mounted) {
        _sendgridApiKeyController.clear();
        _sendgridApiKeyIdController.clear();
        _sendgridFromEmailController.clear();
        _currentSendgridApiKey = null;
        _currentSendgridApiKeyId = null;
        _currentSendgridFromEmail = null;
        _sendgridLastUpdatedBy = null;
        _sendgridLastUpdatedAt = null;
        _showSuccess('SendGrid configuration deleted successfully.');
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to delete SendGrid configuration: $e');
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
        title: const Text('Admin Settings'),
        centerTitle: false,
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
                                  'SendGrid Configuration',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Configure SendGrid for email notifications. Changes take effect immediately when sending invitations.',
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
                      'SendGrid API Key',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _sendgridApiKeyController,
                      obscureText: _obscureSendgridKey,
                      decoration: InputDecoration(
                        hintText: 'SG...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                _obscureSendgridKey ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() => _obscureSendgridKey = !_obscureSendgridKey);
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.content_copy),
                              onPressed: () {
                                final key = _sendgridApiKeyController.text;
                                if (key.isNotEmpty) {
                                  Clipboard.setData(ClipboardData(text: key));
                                  _showSuccess('SendGrid API key copied to clipboard');
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a SendGrid API key';
                        }
                        if (!value.startsWith('SG.')) {
                          return 'SendGrid API key should start with "SG."';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'SendGrid API Key ID',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _sendgridApiKeyIdController,
                      decoration: InputDecoration(
                        hintText: 'Enter API Key ID',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.content_copy),
                          onPressed: () {
                            final keyId = _sendgridApiKeyIdController.text;
                            if (keyId.isNotEmpty) {
                              Clipboard.setData(ClipboardData(text: keyId));
                              _showSuccess('API Key ID copied to clipboard');
                            }
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter a SendGrid API Key ID';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_sendgridLastUpdatedBy != null || _sendgridLastUpdatedAt != null)
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
                                'Last updated${_sendgridLastUpdatedBy != null ? " by $_sendgridLastUpdatedBy" : ""}${_sendgridLastUpdatedAt != null ? " on ${_formatDate(_sendgridLastUpdatedAt!)}" : ""}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      'Verified From Email',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _sendgridFromEmailController,
                      decoration: InputDecoration(
                        hintText: 'no-reply@yourdomain.com',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) {
                          return 'Please enter a verified sender email';
                        }
                        if (!v.contains('@') || v.startsWith('@') || v.endsWith('@')) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enable email delivery'),
                      value: _sendgridEnabled,
                      onChanged: (v) => setState(() => _sendgridEnabled = v),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _saveSendgridConfig,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save),
                            label: Text(_saving ? 'Saving...' : 'Save SendGrid Config'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: scheme.secondary,
                              foregroundColor: scheme.onSecondary,
                            ),
                          ),
                        ),
                        if (_currentSendgridApiKey != null) ...[
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: _saving ? null : _deleteSendgridConfig,
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.red,
                            tooltip: 'Delete SendGrid Config',
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
                                'How to get SendGrid API credentials',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildStep('1', 'Visit app.sendgrid.com'),
                          _buildStep('2', 'Sign in to your account'),
                          _buildStep('3', 'Navigate to Settings > API Keys'),
                          _buildStep('4', 'Click "Create API Key"'),
                          _buildStep('5', 'Copy the API key and ID above'),
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
