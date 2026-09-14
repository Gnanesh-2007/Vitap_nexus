import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

Widget buildPlatformVtopEmbed(String url) {
  final viewType = 'vtop-embed-${url.hashCode}';
  ui_web.platformViewRegistry.registerViewFactory(
    viewType,
    (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..allow = 'fullscreen';
      return iframe;
    },
  );

  return HtmlElementView(viewType: viewType);
}
