import 'package:flutter/material.dart';

class PrimaryGradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool loading;

  const PrimaryGradientButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
  });

  @override
  State<PrimaryGradientButton> createState() =>
      _PrimaryGradientButtonState();
}

class _PrimaryGradientButtonState
    extends State<PrimaryGradientButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled =
        widget.onPressed == null || widget.loading;

    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      child: GestureDetector(
        onTapDown: isDisabled
            ? null
            : (_) => setState(() => _pressed = true),
        onTapUp: isDisabled
            ? null
            : (_) => setState(() => _pressed = false),
        onTapCancel: () =>
            setState(() => _pressed = false),
        onTap: isDisabled ? null : widget.onPressed,
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular(40),
            gradient: isDisabled
                ? null
                : const LinearGradient(
                    colors: [
                      Color(0xFF00C853),
                      Color(0xFF22D3EE),
                    ],
                  ),
            color: isDisabled
                ? Colors.white.withOpacity(0.08)
                : null,
            boxShadow: isDisabled
                ? []
                : [
                    BoxShadow(
                      color: const Color(0xFF00C853)
                          .withOpacity(0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    )
                  ],
          ),
          alignment: Alignment.center,
          child: widget.loading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  widget.text,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
