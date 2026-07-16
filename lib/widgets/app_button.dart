import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color textColor;
  final Color borderColor;
  final double borderWidth;
  final double verticalPadding;
  final double borderRadius;
  final double fontSize;
  final double letterSpacing;

  const AppButton({
    super.key,
    required this.label,
    this.onTap,
    this.backgroundColor = Colors.black,
    this.textColor = Colors.white,
    this.borderColor = Colors.black,
    this.borderWidth = 1.5,
    this.verticalPadding = 14,
    this.borderRadius = 10,
    this.fontSize = 14,
    this.letterSpacing = 1.2,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: verticalPadding),
        decoration: BoxDecoration(
          color: enabled ? backgroundColor : Colors.grey.shade400,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(
            color: enabled ? borderColor : Colors.transparent,
            width: borderWidth,
          ),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              color: enabled ? textColor : Colors.grey.shade600,
              letterSpacing: letterSpacing,
            ),
          ),
        ),
      ),
    );
  }
}
