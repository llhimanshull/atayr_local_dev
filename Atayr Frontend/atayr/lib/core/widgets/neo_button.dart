import 'package:flutter/material.dart';
import '../theme/atayr_colors.dart';
import '../theme/atayr_shadows.dart';

class NeoButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isLoading;
  final IconData? icon;

  const NeoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
    this.icon,
  });

  @override
  State<NeoButton> createState() => _NeoButtonState();
}

class _NeoButtonState extends State<NeoButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    if (!widget.isLoading) {
      widget.onPressed();
    }
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isPrimary ? AtayrColors.accent : AtayrColors.surface;
    final fgColor = AtayrColors.ink;
    
    final offset = _isPressed ? const Offset(4, 4) : const Offset(0, 0);
    final shadows = _isPressed ? AtayrShadows.none : AtayrShadows.standard;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: Transform.translate(
        offset: offset,
        child: Container(
          decoration: BoxDecoration(
            color: bgColor,
            border: Border.all(color: AtayrColors.ink, width: 2),
            boxShadow: shadows,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fgColor,
                  ),
                )
              else if (widget.icon != null) ...[
                Icon(widget.icon, color: fgColor),
                const SizedBox(width: 8),
              ],
              if (!widget.isLoading)
                Flexible(
                  child: Text(
                    widget.label.toUpperCase(),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: fgColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
