import 'package:flutter/material.dart';
import 'package:mrt_wallet/app/core.dart';
import 'dart:ui' as ui;

class LargeTextView extends StatefulWidget {
  const LargeTextView(this.text, {super.key, this.style});
  final List<String> text;
  final TextStyle? style;
  @override
  State<LargeTextView> createState() => _LargeTextViewState();
}

class _LargeTextViewState extends State<LargeTextView> {
  bool showMore = false;
  late final String text = widget.text.join("\n\n");
  void onTap() {
    showMore = !showMore;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: AppGlobalConst.animationDuraion,
      child: LayoutBuilder(
        key: ValueKey(showMore),
        builder: (context, constraints) {
          final span = TextSpan(
              text: text, style: widget.style ?? context.textTheme.bodyMedium);
          final tp = TextPainter(text: span, textDirection: TextDirection.ltr);
          tp.layout(maxWidth: constraints.maxWidth);
          List<ui.LineMetrics> lines = tp.computeLineMetrics();
          if (lines.length > 3 && !showMore) {
            return Wrap(
              alignment: WrapAlignment.end,
              runAlignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                Text(text, maxLines: 3),
                GestureDetector(
                  onTap: onTap,
                  child: Text(
                    "read_more".tr,
                    style: context.textTheme.bodySmall
                        ?.copyWith(color: context.colors.tertiary),
                  ),
                ),
              ],
            );
          }
          return GestureDetector(
              onTap: lines.length > 3 ? onTap : null, child: Text(text));
        },
      ),
    );
  }
}