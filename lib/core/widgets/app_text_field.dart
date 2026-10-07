import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

/// Enhanced text field with validation states, clear button, and helper text.
class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helperText;
  final String? errorText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool obscureText;
  final bool isRequired;
  final bool isReadOnly;
  final bool isClearable;
  final bool autofocus;
  final int? maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final FormFieldValidator<String>? validator;
  final FocusNode? focusNode;

  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.isRequired = false,
    this.isReadOnly = false,
    this.isClearable = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.focusNode,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  bool _hasFocus = false;
  late final FocusNode _internalFocus;

  FocusNode get _focusNode => widget.focusNode ?? _internalFocus;

  @override
  void initState() {
    super.initState();
    _internalFocus = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) _internalFocus.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _hasFocus = _focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Row(
            children: [
              Text(
                widget.label!,
                style: AppTypography.label,
              ),
              if (widget.isRequired) ...[
                const SizedBox(width: 2),
                const Text(
                  '*',
                  style: TextStyle(color: AppColors.error, fontSize: 14),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        TextFormField(
          controller: widget.controller,
          focusNode: _focusNode,
          obscureText: widget.obscureText,
          readOnly: widget.isReadOnly,
          autofocus: widget.autofocus,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onChanged: widget.onChanged,
          validator: widget.validator,
          onFieldSubmitted: widget.onSubmitted != null ? (_) => widget.onSubmitted!() : null,
          decoration: InputDecoration(
            hintText: widget.hint,
            prefixIcon: widget.prefixIcon != null
                ? Icon(widget.prefixIcon, size: 18)
                : null,
            suffixIcon: _buildSuffix(hasError),
            errorText: widget.errorText,
            helperText: hasError ? null : widget.helperText,
            helperMaxLines: 2,
            counterText: '',
          ),
        ),
      ],
    );
  }

  Widget? _buildSuffix(bool hasError) {
    final widgets = <Widget>[];

    if (widget.isClearable && widget.controller?.text.isNotEmpty == true) {
      widgets.add(
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 16),
          splashRadius: 14,
          onPressed: () {
            widget.controller?.clear();
            widget.onChanged?.call('');
          },
        ),
      );
    }

    if (widget.suffixIcon != null) {
      widgets.add(Icon(widget.suffixIcon, size: 18));
    }

    if (widgets.isEmpty) return null;

    if (widgets.length == 1) return widgets.first;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }
}