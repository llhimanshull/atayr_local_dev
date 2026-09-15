import 'package:flutter/material.dart';
import '../theme/atayr_colors.dart';
import '../theme/atayr_shadows.dart';

class NeoInput extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType keyboardType;

  const NeoInput({
    super.key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  State<NeoInput> createState() => _NeoInputState();
}

class _NeoInputState extends State<NeoInput> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AtayrColors.background,
        border: Border.all(
          color: AtayrColors.ink, 
          width: _isFocused ? 3 : 2,
        ),
        boxShadow: _isFocused ? AtayrShadows.none : AtayrShadows.standard,
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        obscureText: widget.obscureText,
        keyboardType: widget.keyboardType,
        style: Theme.of(context).textTheme.bodyLarge,
        cursorColor: AtayrColors.accent,
        cursorWidth: 3,
        decoration: InputDecoration(
          labelText: widget.label,
          labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AtayrColors.ink.withValues(alpha: 0.7),
          ),
          floatingLabelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AtayrColors.ink,
            fontWeight: FontWeight.bold,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
