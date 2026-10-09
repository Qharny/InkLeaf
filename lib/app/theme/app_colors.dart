import 'package:flutter/material.dart';

/// Inkleaf palette: warm cream paper, charcoal ink, sage accent,
/// pencil-yellow highlight.
abstract final class AppColors {
  // Brand roles (from the design spec).
  static const paper = Color(0xFFF6F0E3);
  static const ink = Color(0xFF292B28);
  static const sage = Color(0xFF789477);
  static const pencil = Color(0xFFE8C875);

  // Paper tones.
  static const paperLight = Color(0xFFFBF7EE);
  static const paperDark = Color(0xFFECE3CF);
  static const ruledLine = Color(0xFFDCD2BC);
  static const margin = Color(0xFFE3B5A4);

  // Ink tones.
  static const inkSoft = Color(0xFF5A5C57);
  static const inkFaint = Color(0xFF8E8F88);

  // Accent tones. sageDeep keeps text-on-paper contrast above 4.5:1.
  static const sageDeep = Color(0xFF4F6A4E);
  static const sageLight = Color(0xFFD5E0D2);
  static const pencilLight = Color(0xFFF6E7B9);
  static const pencilDeep = Color(0xFF7A5F14);

  // Status.
  static const error = Color(0xFFB3412F);
  static const errorLight = Color(0xFFF4D9D2);

  // Dark ("night desk") variant.
  static const nightPaper = Color(0xFF1F201E);
  static const nightSurface = Color(0xFF2A2C29);
  static const nightSurfaceHigh = Color(0xFF353733);
  static const nightInk = Color(0xFFEDE6D6);
  static const nightInkSoft = Color(0xFFB9B3A5);
  static const nightLine = Color(0xFF45473F);
  static const nightSage = Color(0xFF9DB89B);

  // Logo tile cream, also the adaptive launcher icon background.
  static const logoCream = Color(0xFFF6E8CC);

  // Pastel note-card fills (blueprint home grid).
  static const noteYellow = Color(0xFFF7E6A8);
  static const noteBlue = Color(0xFFCFDAEC);
  static const noteGreen = Color(0xFFD9E6CB);
  static const notePink = Color(0xFFF3CFC4);
  static const notePurple = Color(0xFFDCD0EC);
  static const notes = <Color>[
    noteYellow,
    noteBlue,
    noteGreen,
    notePink,
    notePurple,
  ];

  // Marker highlights drawn behind headings (translucent).
  static const markerYellow = Color(0x99F2C94C);
  static const markerGreen = Color(0x8C9CC48A);
  static const markerBlue = Color(0x8C9DB9E3);
  static const markerPurple = Color(0x8CC1A7E3);

  // Collection cover / tag colors.
  static const covers = <Color>[
    sage,
    pencil,
    Color(0xFFC98B6B), // terracotta
    Color(0xFF7D95B5), // faded blue
    Color(0xFFB08AB0), // lilac
    Color(0xFF9C8B6E), // kraft
  ];
}
