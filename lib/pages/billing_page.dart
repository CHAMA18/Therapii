import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:therapii/theme.dart';
import 'package:therapii/widgets/primary_button.dart';

/// Elevated billing hub with premium visuals and clear actions.
class BillingPage extends StatelessWidget {
  const BillingPage({super.key});

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
        value: '86%',
        label: 'AI minutes used',
        detail: 'of monthly allowance',
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
        value: '\$48',
        label: 'Credit balance',
        detail: 'applied to next invoice',
        accent: scheme.tertiary,
      ),
    ];

    final invoices = _buildSampleInvoices();

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
                    child: _HeroCard(
                      planName: 'Therapii Premium',
                      priceLabel: '\$189 / month',
                      highlights: const ['Unlimited chat', 'AI voice concierge', 'Analytics vault'],
                      nextBilling: nextBilling,
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
                        onUpdate: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Payment method updates will be available shortly.')),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                      _CreditActionsCard(
                        onRedeem: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Gift code redemption is coming soon.')),
                          );
                        },
                      ),
                      const SizedBox(height: 28),
                      _InvoiceHistory(invoices: invoices),
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
    final color = Theme.of(context).colorScheme.onPrimary;
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
    final color = Theme.of(context).colorScheme.onPrimary.withOpacity(opacity);
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

class _HeroCard extends StatelessWidget {
  final String planName;
  final String priceLabel;
  final List<String> highlights;
  final String nextBilling;

  const _HeroCard({
    required this.planName,
    required this.priceLabel,
    required this.highlights,
    required this.nextBilling,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: scheme.primary.withOpacity(0.08), blurRadius: 42, offset: const Offset(0, 26)),
        ],
      ),
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.16),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.workspace_premium_rounded, color: scheme.primary, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Premium care',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: scheme.primary,
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
          Text(
            'AI-enhanced therapist partnership with voice journaling, session analytics, and concierge escalation.',
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                priceLabel,
                style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Next billing on $nextBilling',
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withOpacity(0.65)),
                  ),
                ),
              ),
            ],
          ),
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
                    color: scheme.primary.withOpacity(0.12),
                    border: Border.all(color: scheme.primary.withOpacity(0.22)),
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
                  label: 'Change plan',
                  leadingIcon: Icons.swap_horiz_rounded,
                  uppercase: false,
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Plan management will be available soon.')),
                    );
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invoice downloads launch shortly.')),
                    );
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Latest invoice'),
                ),
              ),
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
        border: Border.all(color: scheme.outline.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(color: metric.accent.withOpacity(0.12), blurRadius: 30, offset: const Offset(0, 20)),
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
              color: metric.accent.withOpacity(0.14),
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
              color: scheme.onSurface.withOpacity(0.65),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodCard extends StatelessWidget {
  final VoidCallback onUpdate;
  const _PaymentMethodCard({required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: scheme.surface,
        boxShadow: [BoxShadow(color: scheme.primary.withOpacity(0.07), blurRadius: 34, offset: const Offset(0, 22))],
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
                      'Card ending •• 4242 · Expires 08/27 · Auto-renew enabled',
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withOpacity(0.65)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'Update payment method',
            leadingIcon: Icons.edit_rounded,
            uppercase: false,
            onPressed: onUpdate,
          ),
        ],
      ),
    );
  }
}

class _CreditActionsCard extends StatelessWidget {
  final VoidCallback onRedeem;
  const _CreditActionsCard({required this.onRedeem});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: scheme.surface,
        boxShadow: [BoxShadow(color: scheme.primary.withOpacity(0.05), blurRadius: 32, offset: const Offset(0, 20))],
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
                  color: scheme.tertiary.withOpacity(0.18),
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
                      'Apply concierge credits or corporate stipends to reduce upcoming invoices.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withOpacity(0.65), height: 1.5),
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
        boxShadow: [BoxShadow(color: scheme.primary.withOpacity(0.05), blurRadius: 32, offset: const Offset(0, 20))],
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Invoice history', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            'Download detailed receipts or share them with your care team.',
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withOpacity(0.65)),
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
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Invoice ${invoice.id} download coming soon.')),
                    );
                  },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: scheme.outline.withOpacity(0.12)),
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
                                  color: _statusColor(context, invoice.status).withOpacity(0.12),
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
                                            color: _statusColor(context, invoice.status).withOpacity(0.15),
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
                                      style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurface.withOpacity(0.6)),
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

  const _Invoice({
    required this.id,
    required this.amount,
    required this.issuedAt,
    required this.status,
  });
}

enum _InvoiceStatus { paid, dueSoon, overdue }

List<_Invoice> _buildSampleInvoices() {
  final now = DateTime.now();
  return [
    _Invoice(
      id: 'INV-1045',
      amount: 189,
      issuedAt: now.subtract(const Duration(days: 11)),
      status: _InvoiceStatus.paid,
    ),
    _Invoice(
      id: 'INV-1044',
      amount: 189,
      issuedAt: now.subtract(const Duration(days: 41)),
      status: _InvoiceStatus.paid,
    ),
    _Invoice(
      id: 'INV-1043',
      amount: 189,
      issuedAt: now.subtract(const Duration(days: 71)),
      status: _InvoiceStatus.paid,
    ),
  ];
}