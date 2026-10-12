import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Drag-handle bottom sheet used for route options, payment details, etc.
class GSBottomSheet extends StatelessWidget {
  const GSBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.trailing,
    this.initialChildSize = 0.5,
    this.minChildSize = 0.25,
    this.maxChildSize = 0.95,
    this.padding,
  });

  final Widget child;
  final String? title;
  final Widget? trailing;
  final double initialChildSize;
  final double minChildSize;
  final double maxChildSize;
  final EdgeInsetsGeometry? padding;

  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    String? title,
    Widget? trailing,
    double initialChildSize = 0.5,
    double minChildSize = 0.25,
    double maxChildSize = 0.95,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      // Con "quitar animaciones" la hoja aparece sin deslizarse.
      sheetAnimationStyle: MediaQuery.of(context).disableAnimations
          ? AnimationStyle.noAnimation
          : null,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => GSBottomSheet(
        title: title,
        trailing: trailing,
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: GSColors.surface,
            borderRadius: GSRadius.sheetRadius,
            boxShadow: GSShadow.sheet,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: GSSpacing.s3),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: GSColors.line,
                    borderRadius: BorderRadius.circular(GSRadius.full),
                  ),
                ),
              ),

              // Header
              if (title != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: GSSpacing.s4,
                    vertical: GSSpacing.s3,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title!,
                          style: const TextStyle(
                            fontFamily: GSFonts.display,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            color: GSColors.text,
                          ),
                        ),
                      ),
                      if (trailing != null) trailing!,
                    ],
                  ),
                ),

              const Divider(height: 1),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: padding ??
                      EdgeInsets.fromLTRB(GSSpacing.s4, GSSpacing.s4,
                          GSSpacing.s4,
                          GSSpacing.s6 + MediaQuery.of(context).viewInsets.bottom),
                  child: child,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
