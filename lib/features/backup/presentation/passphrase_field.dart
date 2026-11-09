import 'package:flutter/material.dart';

import '../../../ui/theme/morrow_tokens.dart';

/// A labelled, hidden passphrase field with a show/hide button. No
/// autocorrect, suggestions or autofill: the passphrase stays out of the
/// keyboard's learning.
class PassphraseField extends StatefulWidget {
  const PassphraseField({
    required this.label,
    required this.controller,
    this.helperText,
    this.errorText,
    this.onChanged,
    this.onSubmitted,
    this.textInputAction = TextInputAction.done,
    this.enabled = true,
    super.key,
  });

  final String label;
  final TextEditingController controller;

  /// Shown under the field until there is an error, e.g. the length rule.
  final String? helperText;
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
        // The visible label is read as the field's own label below, so it
        // is not read twice.
        ExcludeSemantics(child: Text(widget.label, style: text.labelMedium)),
        const SizedBox(height: MorrowSpacing.sm),
        // Screen readers name the field by its label (drawn above).
        Semantics(
          label: widget.label,
          child: TextField(
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
              helperText: widget.helperText,
              helperMaxLines: 2,
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
        ),
      ],
    );
  }
}
