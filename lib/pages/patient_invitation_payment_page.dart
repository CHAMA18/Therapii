import 'package:flutter/material.dart';
import 'package:therapii/models/invitation_code.dart';
import 'package:therapii/models/therapist.dart';
import 'package:therapii/models/user.dart';
import 'package:therapii/pages/patient_invitation_all_set_page.dart';
import 'package:therapii/services/therapist_service.dart';
import 'package:therapii/services/user_service.dart';

class PatientInvitationPaymentPage extends StatefulWidget {
  final InvitationCode invitation;
  final String patientFirstName;
  final String patientLastName;
  final String patientEmail;
  final bool requiresEmailVerification;

  const PatientInvitationPaymentPage({
    super.key,
    required this.invitation,
    required this.patientFirstName,
    required this.patientLastName,
    required this.patientEmail,
    required this.requiresEmailVerification,
  });

  @override
  State<PatientInvitationPaymentPage> createState() => _PatientInvitationPaymentPageState();
}

class _PatientInvitationPaymentPageState extends State<PatientInvitationPaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final TherapistService _therapistService = TherapistService();
  final UserService _userService = UserService();

  final TextEditingController _nameOnCardCtrl = TextEditingController();
  final TextEditingController _cardNumberCtrl = TextEditingController();
  final TextEditingController _expDateCtrl = TextEditingController();
  final TextEditingController _cvvCtrl = TextEditingController();
  final TextEditingController _billingAddressCtrl = TextEditingController();
  final TextEditingController _cityCtrl = TextEditingController();
  final TextEditingController _zipCtrl = TextEditingController();

  Therapist? _therapist;
  User? _therapistUser;
  bool _isSubmitting = false;
  String? _selectedState;

  static const List<String> _usStates = [
    'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
    'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
    'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
    'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
    'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY',
  ];

  @override
  void initState() {
    super.initState();
    final fullName = [widget.patientFirstName, widget.patientLastName]
        .where((part) => part.trim().isNotEmpty)
        .join(' ');
    _nameOnCardCtrl.text = fullName;
    _billingAddressCtrl.text = '';
    _loadTherapist();
  }

  Future<void> _loadTherapist() async {
    try {
      final therapist = await _therapistService.getTherapist(widget.invitation.therapistId);
      User? therapistUser;

      final needsFallbackUser = therapist == null ||
          therapist.firstName.trim().isEmpty ||
          therapist.lastName.trim().isEmpty;

      if (needsFallbackUser) {
        therapistUser = await _userService.getUser(widget.invitation.therapistId);
      } else if (therapist.userId.trim().isNotEmpty && therapist.userId != widget.invitation.therapistId) {
        therapistUser = await _userService.getUser(therapist.userId);
      }

      if (!mounted) return;
      setState(() {
        _therapist = therapist;
        _therapistUser = therapistUser;
      });
    } catch (_) {
      // If the therapist lookup fails we still show the page with generic copy.
    }
  }

  String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      if (value == null) continue;
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  @override
  void dispose() {
    _nameOnCardCtrl.dispose();
    _cardNumberCtrl.dispose();
    _expDateCtrl.dispose();
    _cvvCtrl.dispose();
    _billingAddressCtrl.dispose();
    _cityCtrl.dispose();
    _zipCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String hint) {
    final borderRadius = BorderRadius.circular(24);
    final borderColor = Colors.grey.shade300;
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: OutlineInputBorder(borderRadius: borderRadius, borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: borderRadius, borderSide: BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: borderRadius, borderSide: BorderSide(color: const Color(0xFF9C5FFF), width: 1.6)),
    );
  }

  Future<void> _handleContinue() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => PatientInvitationAllSetPage(
          requiresEmailVerification: widget.requiresEmailVerification,
          patientEmail: widget.patientEmail,
          therapistId: widget.invitation.therapistId,
          patientFirstName: widget.patientFirstName,
          patientLastName: widget.patientLastName,
        ),
      ));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final therapistFirstName = _firstNonEmpty([
      _therapist?.firstName,
      _therapistUser?.firstName,
    ]);
    final therapistLastName = _firstNonEmpty([
      _therapist?.lastName,
      _therapistUser?.lastName,
    ]);
    final therapistDisplayName = [therapistFirstName, therapistLastName]
        .where((part) => part.isNotEmpty)
        .join(' ');
    final overseerLabel = therapistDisplayName.isNotEmpty
        ? '[$therapistDisplayName]'
        : '[your therapist]';
    final providerLabel = therapistFirstName.isNotEmpty
        ? therapistFirstName
        : (therapistDisplayName.isNotEmpty ? therapistDisplayName : 'Your therapist');

    final headingStyle = (theme.textTheme.headlineMedium ?? theme.textTheme.titleLarge)
        ?.copyWith(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2, color: theme.colorScheme.onSurface);
    final bodyStyle = (theme.textTheme.bodyLarge ?? theme.textTheme.bodyMedium)
        ?.copyWith(fontSize: 16, color: theme.colorScheme.onSurface.withOpacity(0.85), height: 1.5);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Payment Setup'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Congratulations, and welcome to Therapii!',
                      style: headingStyle,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Your account is almost ready for secure, private communications between you and the therapist AI, overseen by $overseerLabel.',
                      style: bodyStyle,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '$providerLabel has provided you with credit for [one] free month(s). You will not be charged until your free month is complete.',
                      style: bodyStyle,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Unlimited use of the Therapii app costs \$150/month, and you can cancel anytime.',
                      style: bodyStyle,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Please provide payment information below.',
                      style: bodyStyle?.copyWith(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(height: 28),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final width = constraints.maxWidth;
                        final isNarrow = width < 520;
                        final canFitThree = width >= 720;

                        Widget buildRow(List<Widget> children) => isNarrow
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  for (int i = 0; i < children.length; i++) ...[
                                    if (i != 0) const SizedBox(height: 16),
                                    children[i],
                                  ],
                                ],
                              )
                            : Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  for (int i = 0; i < children.length; i++) ...[
                                    if (i != 0) const SizedBox(width: 16),
                                    Expanded(child: children[i]),
                                  ],
                                ],
                              );

                        final stateZipRow = isNarrow
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  DropdownButtonFormField<String>(
                                    value: _selectedState,
                                    decoration: _inputDecoration('State'),
                                    items: _usStates
                                        .map((abbr) => DropdownMenuItem(value: abbr, child: Text(abbr)))
                                        .toList(),
                                    onChanged: (value) => setState(() => _selectedState = value),
                                    validator: (value) => value == null || value.isEmpty ? 'State is required.' : null,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _zipCtrl,
                                    decoration: _inputDecoration('Zip'),
                                    keyboardType: TextInputType.number,
                                    validator: (value) => (value == null || value.trim().isEmpty) ? 'Zip code is required.' : null,
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    flex: canFitThree ? 1 : 2,
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedState,
                                      decoration: _inputDecoration('State'),
                                      items: _usStates
                                          .map((abbr) => DropdownMenuItem(value: abbr, child: Text(abbr)))
                                          .toList(),
                                      onChanged: (value) => setState(() => _selectedState = value),
                                      validator: (value) => value == null || value.isEmpty ? 'State is required.' : null,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    flex: 1,
                                    child: TextFormField(
                                      controller: _zipCtrl,
                                      decoration: _inputDecoration('Zip'),
                                      keyboardType: TextInputType.number,
                                      validator: (value) => (value == null || value.trim().isEmpty) ? 'Zip code is required.' : null,
                                    ),
                                  ),
                                ],
                              );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            buildRow([
                              TextFormField(
                                controller: _nameOnCardCtrl,
                                decoration: _inputDecoration('Name On Card'),
                                textCapitalization: TextCapitalization.words,
                                validator: (value) => (value == null || value.trim().isEmpty) ? 'Name on card is required.' : null,
                              ),
                              TextFormField(
                                controller: _cardNumberCtrl,
                                decoration: _inputDecoration('Card Number'),
                                keyboardType: TextInputType.number,
                                validator: (value) => (value == null || value.trim().isEmpty) ? 'Card number is required.' : null,
                              ),
                            ]),
                            const SizedBox(height: 16),
                            buildRow([
                              TextFormField(
                                controller: _expDateCtrl,
                                decoration: _inputDecoration('Exp. Date'),
                                keyboardType: TextInputType.datetime,
                                validator: (value) => (value == null || value.trim().isEmpty) ? 'Expiration date is required.' : null,
                              ),
                              TextFormField(
                                controller: _cvvCtrl,
                                decoration: _inputDecoration('CVV'),
                                keyboardType: TextInputType.number,
                                validator: (value) => (value == null || value.trim().isEmpty) ? 'CVV is required.' : null,
                              ),
                            ]),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _billingAddressCtrl,
                              decoration: _inputDecoration('Billing Address'),
                              textCapitalization: TextCapitalization.words,
                              validator: (value) => (value == null || value.trim().isEmpty) ? 'Billing address is required.' : null,
                            ),
                            const SizedBox(height: 16),
                            isNarrow
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      TextFormField(
                                        controller: _cityCtrl,
                                        decoration: _inputDecoration('City'),
                                        textCapitalization: TextCapitalization.words,
                                        validator: (value) => (value == null || value.trim().isEmpty) ? 'City is required.' : null,
                                      ),
                                      const SizedBox(height: 16),
                                      stateZipRow,
                                    ],
                                  )
                                : Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: canFitThree ? 2 : 3,
                                        child: TextFormField(
                                          controller: _cityCtrl,
                                          decoration: _inputDecoration('City'),
                                          textCapitalization: TextCapitalization.words,
                                          validator: (value) => (value == null || value.trim().isEmpty) ? 'City is required.' : null,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: canFitThree ? 1 : 2,
                                        child: stateZipRow,
                                      ),
                                    ],
                                  ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                          textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        onPressed: _isSubmitting ? null : _handleContinue,
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                              )
                            : const Text('Continue'),
                      ),
                    ),
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
