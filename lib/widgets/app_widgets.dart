import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_colors.dart';

/// White rounded card.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double radius;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = Colors.white,
    this.radius = 20,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Section heading with an optional green link on the right.
class SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionTitle(this.title, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.teal,
              ),
            ),
          ),
      ],
    );
  }
}

/// Round avatar with initials.
class InitialsAvatar extends StatelessWidget {
  final String initials;
  final double size;

  const InitialsAvatar(this.initials, {super.key, this.size = 52});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.mint,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.31,
          fontWeight: FontWeight.w700,
          color: AppColors.teal,
        ),
      ),
    );
  }
}

/// Small rounded label.
class Pill extends StatelessWidget {
  final String text;
  final Color background;
  final Color foreground;

  const Pill(this.text,
      {super.key, required this.background, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: foreground,
        ),
      ),
    );
  }
}

/// Status chip: Active, Partial, Overdue, Settled.
class StatusChip extends StatelessWidget {
  final String status;
  final String? label;

  const StatusChip(this.status, {super.key, this.label});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'Partial' => (AppColors.amberBg, AppColors.amberText),
      'Active' => (AppColors.mint, AppColors.teal),
      'Overdue' => (AppColors.redBg, AppColors.red),
      _ => (AppColors.greyBg, AppColors.greyText),
    };
    return Pill(label ?? status, background: bg, foreground: fg);
  }
}

/// Grey bar with a white selected tab (Given/Taken, Monthly/Yearly ...).
class SegmentTabs extends StatelessWidget {
  final List<String> options;
  final int selected; // -1 = nothing selected
  final ValueChanged<int> onChanged;

  const SegmentTabs({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.greyBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    options[i],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                      i == selected ? FontWeight.w700 : FontWeight.w500,
                      color:
                      i == selected ? AppColors.teal : AppColors.textGrey,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textGrey,
      ),
    );
  }
}

class HintText extends StatelessWidget {
  final String text;

  const HintText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.textGrey),
    );
  }
}

OutlineInputBorder _fieldBorder(Color color) => OutlineInputBorder(
  borderRadius: BorderRadius.circular(16),
  borderSide: BorderSide(color: color),
);

/// Label above a white text field.
class AppTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final String? prefixText;
  final String? suffixText;
  final IconData? suffixIcon;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final bool obscureText;

  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.prefixText,
    this.suffixText,
    this.suffixIcon,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.readOnly = false,
    this.obscureText = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget? suffix;
    if (suffixIcon != null) {
      suffix = Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Icon(suffixIcon, color: AppColors.textGrey),
      );
    } else if (suffixText != null) {
      suffix = Padding(
        padding: const EdgeInsets.only(right: 18),
        child: Text(
          suffixText!,
          style: const TextStyle(fontSize: 17, color: AppColors.textDark),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          readOnly: readOnly,
          obscureText: obscureText,
          style: const TextStyle(fontSize: 17, color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFA2B2B6)),
            prefixIcon: prefixText == null
                ? null
                : Padding(
              padding: const EdgeInsets.only(left: 18, right: 6),
              child: Text(
                prefixText!,
                style: const TextStyle(
                    fontSize: 17, color: AppColors.textDark),
              ),
            ),
            prefixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixIcon: suffix,
            suffixIconConstraints:
            const BoxConstraints(minWidth: 0, minHeight: 0),
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.fromLTRB(
              prefixText == null ? 18 : 0,
              18,
              18,
              18,
            ),
            border: _fieldBorder(AppColors.border),
            enabledBorder: _fieldBorder(AppColors.border),
            focusedBorder: _fieldBorder(AppColors.teal),
          ),
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: HintText(helper!),
          ),
      ],
    );
  }
}

/// Looks like a text field but opens a picker (dates, contacts ...).
class PickerField extends StatelessWidget {
  final String label;
  final String value;
  final bool isPlaceholder;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onIconTap;
  final String? helper;

  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.isPlaceholder = false,
    this.onIconTap,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        const SizedBox(height: 8),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 0, 6, 0),
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      color: isPlaceholder
                          ? const Color(0xFFA2B2B6)
                          : AppColors.textDark,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onIconTap ?? onTap,
                  icon: Icon(icon, color: AppColors.textGrey, size: 22),
                ),
              ],
            ),
          ),
        ),
        if (helper != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: HintText(helper!),
          ),
      ],
    );
  }
}

/// White circle with an icon (bell, filter, add person ...).
class CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const CircleIconButton({super.key, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: AppColors.textDark, size: 22),
        ),
      ),
    );
  }
}

/// Page used for screens opened on top of the tabs: back arrow, title,
/// scrolling content and an optional fixed bottom button.
class SubScreen extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final Widget? bottom;

  const SubScreen({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.trailing,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              subtitle!,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textGrey,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
            Expanded(child: child),
            if (bottom != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}

/// "Label ........ value" row.
class KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool boldLabel;

  const KeyValueRow(
      this.label,
      this.value, {
        super.key,
        this.valueColor,
        this.boldLabel = false,
      });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: boldLabel ? FontWeight.w600 : FontWeight.w400,
                color: boldLabel ? AppColors.textDark : AppColors.textGrey,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: valueColor ?? AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

/// Teal on/off switch.
class AppSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const AppSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
            ? AppColors.teal
            : const Color(0xFFD3DDDB),
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    );
  }
}

/// Bottom sheet with a list of choices. Returns the chosen index.
Future<int?> showOptionSheet(
    BuildContext context, {
      required String title,
      required List<String> options,
      int? selected,
    }) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (_, i) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  title: Text(
                    options[i],
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                      i == selected ? FontWeight.w700 : FontWeight.w400,
                      color: AppColors.textDark,
                    ),
                  ),
                  trailing: i == selected
                      ? const Icon(Icons.check, color: AppColors.teal)
                      : null,
                  onTap: () => Navigator.pop(ctx, i),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// Quick message at the bottom of the screen.
void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}
