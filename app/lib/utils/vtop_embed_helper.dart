import 'package:flutter/material.dart';
import 'vtop_embed_stub.dart'
    if (dart.library.js_interop) 'vtop_embed_web.dart';

Widget buildVtopEmbed(String url) => buildPlatformVtopEmbed(url);
