import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// iPad requires [sharePositionOrigin] or the share sheet may not appear.
Future<void> shareTextFromContext(
  BuildContext context,
  String text, {
  String? subject,
}) async {
  final origin = _shareOriginRect(context);
  await Share.share(
    text,
    subject: subject,
    sharePositionOrigin: origin,
  );
}

Rect _shareOriginRect(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is RenderBox && renderObject.hasSize) {
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    if (size.width > 0 && size.height > 0) {
      return topLeft & size;
    }
  }
  final size = MediaQuery.sizeOf(context);
  return Rect.fromCenter(
    center: Offset(size.width * 0.5, size.height * 0.35),
    width: 48,
    height: 48,
  );
}
