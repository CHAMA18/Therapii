import 'dart:ui';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:therapii/theme.dart';
import 'package:therapii/widgets/primary_button.dart';
import 'package:url_launcher/url_launcher.dart';

/// Elevated billing hub with premium visuals and clear actions.
class BillingPage extends StatefulWidget {
  const BillingPage({super.key});

  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  List<_Invoice> _invoices = [];
  bool _isLoadingInvoices = true;
  bool _isLoadingBilling = true;
  
  // Billing data from Stripe
  bool _isPaidUser = false;
  String _planName = 'Free Plan';
  double _creditBalance = 0;
  _PaymentMethodData? _paymentMethod;
  String? _nextBillingDate;
  _AppliedCoupon? _appliedCoupon;

  @override
  void initState() {
    super.initState();
    _fetchBillingDetails();
    _fetchInvoices();
  }

  Future<void> _fetchBillingDetails() async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('getStripeBillingDetails');
      final result = await callable.call();
      
      final data = result.data as Map<String, dynamic>;
      
      if (mounted) {
        setState(() {
          _isPaidUser = data['isPaidUser'] == true;
          _planName = data['planName'] as String? ?? 'Free Plan';
          _creditBalance = (data['creditBalance'] as num?)?.toDouble() ?? 0;
          _nextBillingDate = data['nextBillingDate'] as String?;
          
          if (data['paymentMethod'] != null) {
            final pm = data['paymentMethod'] as Map<String, dynamic>;
            _paymentMethod = _PaymentMethodData(
              brand: pm['brand'] as String? ?? 'card',
              last4: pm['last4'] as String? ?? '****',
              expMonth: pm['expMonth'] as int? ?? 1,
              expYear: pm['expYear'] as int? ?? 2030,
            );
          }
          
          if (data['appliedCoupon'] != null) {
            final coupon = data['appliedCoupon'] as Map<String, dynamic>;
            _appliedCoupon = _AppliedCoupon(
              code: coupon['code'] as String? ?? '',
              name: coupon['name'] as String? ?? '',
              percentOff: (coupon['percentOff'] as num?)?.toDouble(),
              amountOff: (coupon['amountOff'] as num?)?.toDouble(),
            );
          }
          
          _isLoadingBilling = false;
        });
      }
    } catch (error) {
      debugPrint('Error fetching billing details: $error');
      if (mounted) {
        setState(() => _isLoadingBilling = false);
      }
    }
  }

  Future<void> _fetchInvoices() async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('getStripeInvoices');
      final result = await callable.call();
      
      final invoicesData = result.data['invoices'] as List<dynamic>? ?? [];
      final fetchedInvoices = invoicesData.map((invoice) {
        return _Invoice(
          id: invoice['id'] as String? ?? '',
          amount: (invoice['amount'] as num?)?.toDouble() ?? 0.0,
          issuedAt: DateTime.tryParse(invoice['issuedAt'] as String? ?? '') ?? DateTime.now(),
          status: _InvoiceStatus.paid,
          invoiceUrl: invoice['invoiceUrl'] as String?,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _invoices = fetchedInvoices;
          _isLoadingInvoices = false;
        });
      }
    } catch (error) {
      debugPrint('Error fetching invoices: $error');
      if (mounted) {
        setState(() {
          _invoices = [];
          _isLoadingInvoices = false;
        });
      }
    }
  }

  Future<void> _showRedeemCodeDialog(BuildContext context) async {
    final codeController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Redeem Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your gift or credit code below:'),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Code',
                hintText: 'Enter code',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Redeem'),
          ),
        ],
      ),
    );

    if (result == true && codeController.text.trim().isNotEmpty && mounted) {
      try {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Redeeming code...')),
        );
        
        final callable = FirebaseFunctions.instance.httpsCallable('redeemStripeCode');
        final response = await callable.call({'code': codeController.text.trim()});
        final data = response.data as Map<String, dynamic>;
        
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] as String? ?? 'Code redeemed successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh billing data
          _fetchBillingDetails();
        }
      } catch (e) {
        debugPrint('Error redeeming code: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to redeem code: ${e.toString().replaceAll('Exception: ', '')}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    codeController.dispose();
  }

  Future<void> _handleChangePlan(BuildContext context) async {
    try {
      // Show loading indicator
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Opening Stripe Checkout...')),
      );

      // Call Cloud Function to create Checkout Session
      final callable = FirebaseFunctions.instance.httpsCallable('createStripeCheckoutSession');
      
      // Get current URL for success/cancel redirects
      final baseUrl = kIsWeb ? Uri.base.toString().replaceAll(RegExp(r'[?#].*'), '') : 'https://therapii.app';
      
      final result = await callable.call({
        'priceId': 'price_1SOt2aL9fA3Th1kO32maIqxk',
        'successUrl': '$baseUrl/billing?success=true',
        'cancelUrl': '$baseUrl/billing?cancelled=true',
      });

      final checkoutUrl = result.data['url'] as String?;
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw Exception('No checkout URL returned');
      }

      // Open Stripe Checkout in browser
      final uri = Uri.parse(checkoutUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Could not launch checkout URL');
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Firebase Functions error: ${e.code} - ${e.message}');
      debugPrint('Details: ${e.details}');
      
      if (!context.mounted) return;
      
      // Provide specific error messages
      String errorMessage;
      if (e.code == 'not-found' || e.code == 'internal') {
        errorMessage = 'Cloud Functions not deployed yet.\n\nPlease deploy functions first:\n1. Download project code\n2. Run: firebase deploy --only functions';
      } else {
        errorMessage = 'Error: ${e.message ?? e.code}';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (error) {
      debugPrint('Error creating checkout session: $error');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open checkout: ${error.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final brightness = theme.brightness;
    final localizations = MaterialLocalizations.of(context);
    final nextBilling = localizations.formatFullDate(DateTime.now().add(const Duration(days: 11)));

    final metrics = <_MetricData>[
      _MetricData(
        icon: Icons.auto_graph_rounded,
        value: _isPaidUser ? 'Unlimited' : '0%',
        label: 'AI minutes used',
        detail: _isPaidUser ? 'Unlimited usage' : 'Upgrade for unlimited',
        accent: scheme.primary,
      ),
      _MetricData(
        icon: Icons.schedule_rounded,
        value: '4',
        label: 'Therapist sessions',
        detail: 'completed this month',
        accent: scheme.secondary,
      ),
      _MetricData(
        icon: Icons.card_giftcard_rounded,
        value: '\$${_creditBalance.toStringAsFixed(0)}',
        label: 'Credit balance',
        detail: _creditBalance > 0 ? 'applied to next invoice' : 'No credits yet',
        accent: scheme.tertiary,
      ),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Billing & Plans'),
        leading: IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 260,
              decoration: BoxDecoration(
                gradient: AppGradients.primaryFor(brightness),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(42),
                  bottomRight: Radius.circular(42),
                ),
              ),
              child: const _BackdropOrbs(),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 520),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, child) => Transform.translate(
                        offset: Offset(0, (1 - v) * 24),
                        child: Opacity(opacity: v, child: child),
                      ),
                      child: _isLoadingBilling
                        ? const _HeroCardShimmer()
                        : _HeroCard(
                            planName: _planName,
                            isPaidUser: _isPaidUser,
                            highlights: _isPaidUser 
                              ? const ['Unlimited chat', 'AI voice concierge', 'Analytics vault']
                              : const ['Basic chat', 'Session summaries'],
                            nextBilling: _nextBillingDate != null 
                              ? localizations.formatFullDate(DateTime.parse(_nextBillingDate!))
                              : null,
                            onChangePlan: () => _handleChangePlan(context),
                            latestInvoice: _invoices.isNotEmpty ? _invoices.first : null,
                          ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverToBoxAdapter(
                    child: _MetricsGrid(metrics: metrics),
                  ),
                ),
                const SliverPadding(padding: EdgeInsets.only(top: 24)),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate.fixed([
                      _PaymentMethodCard(
                        paymentMethod: _paymentMethod,
                        isPaidUser: _isPaidUser,
                        isLoading: _isLoadingBilling,
                        onUpdate: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Payment method updates will be available shortly.')),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _CreditActionsCard(
                        appliedCoupon: _appliedCoupon,
                        onRedeem: () => _showRedeemCodeDialog(context),
                      ),
                      if (_isLoadingInvoices) ...[
                        const SizedBox(height: 28),
                        const Center(child: CircularProgressIndicator()),
                      ] else if (_invoices.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _InvoiceHistory(invoices: _invoices),
                      ],
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackdropOrbs extends StatelessWidget {
  const _BackdropOrbs();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: const [
        _FrostedOrb(size: 190, opacity: 0.16, alignment: Alignment(1.1, -1.1)),
        _FrostedOrb(size: 220, opacity: 0.12, alignment: Alignment(-1.2, 1.1)),
      ],
    );
  }
}

class _FrostedOrb extends StatelessWidget {
  final double size;
  final double opacity;
  final Alignment alignment;

  const _FrostedOrb({required this.size, required this.opacity, required this.alignment});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onPrimary.withValues(alpha: opacity);
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [BoxShadow(color: color, blurRadius: 70, spreadRadius: 16)],
        ),
      ),
    );
  }
}

class _HeroCardShimmer extends StatelessWidget {
  const _HeroCardShimmer();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: scheme.primary.withValues(alpha: 0.08), blurRadius: 42, offset: const Offset(0, 26)),
        ],
      ),
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 120, height: 32, decoration: BoxDecoration(color: scheme.outline.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(18))),
          const SizedBox(height: 18),
          Container(width: 200, height: 28, decoration: BoxDecoration(color: scheme.outline.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 12),
          Container(width: double.infinity, height: 48, decoration: BoxDecoration(color: scheme.outline.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 22),
          Container(width: 150, height: 36, decoration: BoxDecoration(color: scheme.outline.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8))),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String planName;
  final bool isPaidUser;
  final List<String> highlights;
  final String? nextBilling;
  final VoidCallback onChangePlan;
  final _Invoice? latestInvoice;

  const _HeroCard({
    required this.planName,
    required this.isPaidUser,
    required this.highlights,
    this.nextBilling,
    required this.onChangePlan,
    this.latestInvoice,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final badgeColor = isPaidUser ? scheme.primary : scheme.tertiary;
    final badgeLabel = isPaidUser ? 'Premium care' : 'Free tier';
    final description = isPaidUser
      ? 'AI-enhanced therapist partnership with voice journaling, session analytics, and concierge escalation.'
      : 'Get started with basic chat support and session summaries. Upgrade for unlimited AI access.';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: scheme.primary.withValues(alpha: 0.08), blurRadius: 42, offset: const Offset(0, 26)),
        ],
      ),
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isPaidUser ? Icons.workspace_premium_rounded : Icons.star_outline_rounded, color: badgeColor, size: 18),
                const SizedBox(width: 8),
                Text(
                  badgeLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: badgeColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            planName,
            style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.3),
          ),
          const SizedBox(height: 8),
          Text(description, style: theme.textTheme.bodyLarge?.copyWith(height: 1.55)),
          if (nextBilling != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 16, color: scheme.onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: 8),
                Text(
                  'Next billing on $nextBilling',
                  style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.65)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final highlight in highlights)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: scheme.primary.withValues(alpha: 0.12),
                    border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 16, color: scheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        highlight,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 26),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: isPaidUser ? 'Manage plan' : 'Upgrade now',
                  leadingIcon: isPaidUser ? Icons.settings_rounded : Icons.rocket_launch_rounded,
                  uppercase: false,
                  onPressed: onChangePlan,
                ),
              ),
              if (latestInvoice != null) ...[
                const SizedBox(width: 14),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      if (latestInvoice?.invoiceUrl != null && latestInvoice!.invoiceUrl!.isNotEmpty) {
                        try {
                          final uri = Uri.parse(latestInvoice!.invoiceUrl!);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Could not open invoice PDF.')),
                              );
                            }
                          }
                        } catch (error) {
                          debugPrint('Error opening invoice: $error');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: ${error.toString()}')),
                            );
                          }
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('No invoice available yet.')),
                        );
                      }
                    },
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Latest invoice'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricData {
  final IconData icon;
  final String value;
  final String label;
  final String detail;
  final Color accent;

  const _MetricData({
    required this.icon,
    required this.value,
    required this.label,
    required this.detail,
    required this.accent,
  });
}

class _MetricsGrid extends StatelessWidget {
  final List<_MetricData> metrics;
  const _MetricsGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 720;
        final crossAxisCount = isWide ? metrics.length : 1;
        final spacing = 16.0;
        final itemWidth = (constraints.maxWidth - spacing * (crossAxisCount - 1)) / crossAxisCount;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: itemWidth,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 480),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Transform.translate(
                    offset: Offset(0, (1 - value) * 22),
                    child: Opacity(opacity: value, child: child),
                  ),
                  child: _MetricTile(metric: metric),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  final _MetricData metric;
  const _MetricTile({required this.metric});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: scheme.surface,
        border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(color: metric.accent.withValues(alpha: 0.12), blurRadius: 30, offset: const Offset(0, 20)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 46,
            width: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: metric.accent.withValues(alpha: 0.14),
            ),
            child: Icon(metric.icon, color: metric.accent),
          ),
          const SizedBox(height: 18),
          Text(
            metric.value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: metric.accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(metric.label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            metric.detail,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withValues(alpha: 0.65),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodData {
  final String brand;
  final String last4;
  final int expMonth;
  final int expYear;

  const _PaymentMethodData({
    required this.brand,
    required this.last4,
    required this.expMonth,
    required this.expYear,
  });

  String get brandDisplay {
    switch (brand.toLowerCase()) {
      case 'visa': return 'Visa';
      case 'mastercard': return 'Mastercard';
      case 'amex': return 'Amex';
      case 'discover': return 'Discover';
      default: return brand.isNotEmpty ? brand[0].toUpperCase() + brand.substring(1) : 'Card';
    }
  }
}

class _AppliedCoupon {
  final String code;
  final String name;
  final double? percentOff;
  final double? amountOff;

  const _AppliedCoupon({
    required this.code,
    required this.name,
    this.percentOff,
    this.amountOff,
  });
}

class _PaymentMethodCard extends StatelessWidget {
  final _PaymentMethodData? paymentMethod;
  final bool isPaidUser;
  final bool isLoading;
  final VoidCallback onUpdate;
  const _PaymentMethodCard({this.paymentMethod, this.isPaidUser = false, this.isLoading = false, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    String cardInfo;
    if (isLoading) {
      cardInfo = 'Loading payment information...';
    } else if (paymentMethod != null) {
      final pm = paymentMethod!;
      final expStr = '${pm.expMonth.toString().padLeft(2, '0')}/${pm.expYear.toString().substring(2)}';
      cardInfo = '${pm.brandDisplay} ending •• ${pm.last4} · Expires $expStr · Auto-renew ${isPaidUser ? 'enabled' : 'disabled'}';
    } else {
      cardInfo = 'No payment method on file';
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: scheme.surface,
        boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.07), blurRadius: 34, offset: const Offset(0, 22))],
      ),
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [scheme.primary, scheme.primaryContainer],
                  ),
                ),
                child: Icon(Icons.credit_card_rounded, color: scheme.onPrimary),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Payment method', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(
                      cardInfo,
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.65)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: paymentMethod != null ? 'Update payment method' : 'Add payment method',
            leadingIcon: paymentMethod != null ? Icons.edit_rounded : Icons.add_rounded,
            uppercase: false,
            onPressed: onUpdate,
          ),
        ],
      ),
    );
  }
}

class _CreditActionsCard extends StatelessWidget {
  final _AppliedCoupon? appliedCoupon;
  final VoidCallback onRedeem;
  const _CreditActionsCard({this.appliedCoupon, required this.onRedeem});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    String subtitle;
    if (appliedCoupon != null) {
      final coupon = appliedCoupon!;
      if (coupon.amountOff != null) {
        subtitle = 'Active coupon: ${coupon.name} (\$${coupon.amountOff!.toStringAsFixed(0)} off)';
      } else if (coupon.percentOff != null) {
        subtitle = 'Active coupon: ${coupon.name} (${coupon.percentOff!.toStringAsFixed(0)}% off)';
      } else {
        subtitle = 'Active coupon: ${coupon.name}';
      }
    } else {
      subtitle = 'Apply concierge credits or corporate stipends to reduce upcoming invoices.';
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: scheme.surface,
        boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.05), blurRadius: 32, offset: const Offset(0, 20))],
      ),
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: scheme.tertiary.withValues(alpha: 0.18),
                ),
                child: Icon(Icons.card_giftcard_rounded, color: scheme.tertiary),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gift or credit code', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: appliedCoupon != null ? scheme.primary : scheme.onSurface.withValues(alpha: 0.65),
                        height: 1.5,
                        fontWeight: appliedCoupon != null ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRedeem,
                  icon: const Icon(Icons.qr_code_rounded),
                  label: const Text('Redeem code'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Share credits from your therapist portal.')),
                    );
                  },
                  icon: const Icon(Icons.share_arrival_time_rounded),
                  label: const Text('Share credits'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvoiceHistory extends StatelessWidget {
  final List<_Invoice> invoices;
  const _InvoiceHistory({required this.invoices});

  Color _statusColor(BuildContext context, _InvoiceStatus status) {
    final scheme = Theme.of(context).colorScheme;
    switch (status) {
      case _InvoiceStatus.paid:
        return scheme.primary;
      case _InvoiceStatus.dueSoon:
        return scheme.secondary;
      case _InvoiceStatus.overdue:
        return scheme.error;
    }
  }

  String _statusLabel(_InvoiceStatus status) {
    switch (status) {
      case _InvoiceStatus.paid:
        return 'Paid';
      case _InvoiceStatus.dueSoon:
        return 'Due soon';
      case _InvoiceStatus.overdue:
        return 'Overdue';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final localizations = MaterialLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: scheme.surface,
        boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.05), blurRadius: 32, offset: const Offset(0, 20))],
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Invoice history', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'Download detailed receipts or share them with your care team.',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.65)),
          ),
          const SizedBox(height: 20),
          for (final invoice in invoices)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Material(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    if (invoice.invoiceUrl != null && invoice.invoiceUrl!.isNotEmpty) {
                      try {
                        final uri = Uri.parse(invoice.invoiceUrl!);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Could not open invoice PDF.')),
                            );
                          }
                        }
                      } catch (error) {
                        debugPrint('Error opening invoice: $error');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: ${error.toString()}')),
                          );
                        }
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invoice PDF not available.')),
                      );
                    }
                  },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: scheme.outline.withValues(alpha: 0.12)),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 360;

                          final amountSection = Column(
                            crossAxisAlignment: isCompact ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatAmount(invoice.amount),
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tap to download',
                                style: theme.textTheme.labelMedium?.copyWith(color: scheme.primary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          );

                          final mainRow = Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: _statusColor(context, invoice.status).withValues(alpha: 0.12),
                                ),
                                child: Icon(
                                  invoice.status == _InvoiceStatus.paid
                                      ? Icons.receipt_long_rounded
                                      : Icons.error_outline_rounded,
                                  color: _statusColor(context, invoice.status),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            invoice.id,
                                            style: theme.textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              fontFeatures: const [FontFeature.tabularFigures()],
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: _statusColor(context, invoice.status).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            _statusLabel(invoice.status),
                                            style: theme.textTheme.labelMedium?.copyWith(
                                              color: _statusColor(context, invoice.status),
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      localizations.formatMediumDate(invoice.issuedAt),
                                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withValues(alpha: 0.6)),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isCompact) ...[
                                const SizedBox(width: 18),
                                amountSection,
                              ],
                            ],
                          );

                          if (!isCompact) {
                            return mainRow;
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              mainRow,
                              const SizedBox(height: 12),
                              amountSection,
                            ],
                          );
                        },
                      ),
                    ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) => '\$${amount.toStringAsFixed(2)}';
}

class _Invoice {
  final String id;
  final double amount;
  final DateTime issuedAt;
  final _InvoiceStatus status;
  final String? invoiceUrl;

  const _Invoice({
    required this.id,
    required this.amount,
    required this.issuedAt,
    required this.status,
    this.invoiceUrl,
  });
}

enum _InvoiceStatus { paid, dueSoon, overdue }