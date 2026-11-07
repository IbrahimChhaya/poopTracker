import 'package:flutter/material.dart';

import '../theme/morrow_colors.dart';
import '../theme/morrow_tokens.dart';
import 'icon_tile.dart';

/// A row inside a [CardGroup]: icon tile, title, optional subtitle, and a
/// chevron (navigation) or a switch.
class SettingRow extends StatelessWidget {
  /// A row that opens another screen.
  const SettingRow.navigation({
    required this.icon,
    required this.title,
    required VoidCallback this.onTap,
    this.subtitle,
    this.destructive = false,
    super.key,
  }) : value = false,
       onChanged = null,
       _isToggle = false;

  /// A row with an on/off switch. Tapping anywhere on the row toggles it.
  const SettingRow.toggle({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    super.key,
  }) : onTap = null,
       destructive = false,
       _isToggle = true;

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool value;
  final ValueChanged<bool>? onChanged;

  /// Danger styling, for example "Delete all data".
  final bool destructive;

  final bool _isToggle;

  @override
  Widget build(BuildContext context) {
    final colors = MorrowColors.of(context);
    final text = Theme.of(context).textTheme;
    final sub = subtitle;

    final Widget trailing = _isToggle
        ? Switch(value: value, onChanged: onChanged)
        : Icon(Icons.chevron_right, size: 20, color: colors.mutedIcon);

    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: MorrowSpacing.lg,
        vertical: 14,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconTile(
            icon: icon,
            tone: destructive ? IconTileTone.warm : IconTileTone.neutral,
          ),
          const SizedBox(width: MorrowSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: text.bodyLarge!.copyWith(
                    fontWeight: FontWeight.w500,
                    color: destructive ? colors.danger : colors.ink,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: MorrowSpacing.xxs),
                  Text(sub, style: text.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: MorrowSpacing.md),
          ExcludeSemantics(excluding: !_isToggle, child: trailing),
        ],
      ),
    );

    if (_isToggle) {
      final changed = onChanged;
      return MergeSemantics(
        child: InkWell(
          onTap: changed == null ? null : () => changed(!value),
          child: row,
        ),
      );
    }
    return Semantics(
      button: true,
      child: InkWell(onTap: onTap, child: row),
    );
  }
}
