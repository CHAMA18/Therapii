import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class RoundedTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  const RoundedTextField({super.key, required this.controller, required this.hintText, this.keyboardType = TextInputType.text, this.obscureText = false, this.suffixIcon});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5), width: 1.2),
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }
}

class PasswordTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  const PasswordTextField({super.key, required this.controller, required this.hintText});

  @override
  State<PasswordTextField> createState() => _PasswordTextFieldState();
}

class _PasswordTextFieldState extends State<PasswordTextField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return RoundedTextField(
      controller: widget.controller,
      hintText: widget.hintText,
      obscureText: _obscure,
      suffixIcon: IconButton(
        icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade600),
        onPressed: () => setState(() => _obscure = !_obscure),
      ),
    );
  }
}

class TermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String label;
  final String underlined;
  final VoidCallback? onLinkTap;
  const TermsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    required this.underlined,
    this.onLinkTap,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium;
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      dense: true,
      title: RichText(
        text: TextSpan(
          children: [
            TextSpan(text: label + ' ', style: textStyle),
            TextSpan(
              text: underlined,
              style: textStyle?.copyWith(
                decoration: TextDecoration.underline,
                fontWeight: FontWeight.w600,
              ),
              recognizer: (onLinkTap == null)
                  ? null
                  : (TapGestureRecognizer()..onTap = onLinkTap),
            ),
          ],
        ),
        softWrap: true,
      ),
    );
  }
}
