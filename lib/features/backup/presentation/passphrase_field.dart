import 'package:flutter/material.dart';

import '../../../ui/theme/morrow_tokens.dart';

/// A labelled, hidden passphrase field with a show/hide button. No
/// autocorrect, suggestions or autofill: the passphrase stays out of the
/// keyboard's learning.
class PassphraseField extends StatefulWidget {
  const PassphraseField({
    required this.label,
    required this.controller,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.done,
    this.enabled = true,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction textInputAction;
  final bool enabled;

  @override
  State<PassphraseField> createState() => _PassphraseFieldState();
}

class _PassphraseFieldState extends State<PassphraseField> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.label, style: text.bodySmall),
        const SizedBox(height: MorrowSpacing.sm),
        TextField(
          controller: widget.controller,
          enabled: widget.enabled,
          obscureText: !_shown,
          autocorrect: false,
          enableSuggestions: false,
          enableIMEPersonalizedLearning: false,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: widget.textInputAction,
          onChanged: widget.onChanged,
          onSubmitted: widget.onSubmitted,
          decoration: InputDecoration(
            semanticCounterText: '',
            errorText: widget.errorText,
            errorMaxLines: 3,
            suffixIcon: IconButton(
              tooltip: _shown ? 'Hide passphrase' : 'Show passphrase',
              onPressed: () => setState(() => _shown = !_shown),
              icon: Icon(
                _shown
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
