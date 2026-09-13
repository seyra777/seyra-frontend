import 'package:flutter/material.dart';
import 'package:seyra/core/theme/app_colors.dart';

class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.obscureable = false,
    this.prefixIcon,
    this.validator,
    this.textInputAction,
    this.autofillHints,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String label;
  final bool obscureable;
  final IconData? prefixIcon;
  final FormFieldValidator<String>? validator;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool enabled;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscured = widget.obscureable;

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark(context);
    final radius = BorderRadius.circular(dark ? 28 : 18);
    final fill = dark ? AppColors.darkInputFill : AppColors.surfaceMuted;
    final borderColor = dark
        ? AppColors.darkInputBorder
        : AppColors.fieldBorder;
    final focusColor = dark ? AppColors.darkCyan : AppColors.primary;
    final iconColor = dark
        ? AppColors.darkSecondaryText
        : AppColors.textSecondary;
    final textColor = dark ? Colors.white : AppColors.textPrimary;

    OutlineInputBorder border(Color color, {double width = 1.2}) {
      return OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      obscureText: _obscured,
      autocorrect: !widget.obscureable,
      enableSuggestions: !widget.obscureable,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      style: TextStyle(
        color: textColor,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      cursorColor: focusColor,
      decoration: InputDecoration(
        hintText: widget.label,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        hintStyle: TextStyle(
          color: iconColor,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: widget.prefixIcon == null
            ? null
            : Icon(widget.prefixIcon, color: iconColor),
        prefixIconColor: iconColor,
        suffixIconColor: iconColor,
        suffixIcon: widget.obscureable
            ? IconButton(
                onPressed: widget.enabled
                    ? () => setState(() => _obscured = !_obscured)
                    : null,
                icon: Icon(
                  _obscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: dark ? Colors.white70 : iconColor,
                ),
              )
            : null,
        border: border(borderColor),
        enabledBorder: border(borderColor),
        disabledBorder: border(borderColor.withValues(alpha: 0.5)),
        focusedBorder: border(focusColor, width: 1.6),
        errorBorder: border(Theme.of(context).colorScheme.error),
        focusedErrorBorder: border(
          Theme.of(context).colorScheme.error,
          width: 1.6,
        ),
      ),
    );
  }
}
