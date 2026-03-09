import 'package:flutter/material.dart';

class MemberAccentColor {
  const MemberAccentColor({
    required this.name,
    required this.hex,
    required this.color,
  });

  final String name;
  final String hex;
  final Color color;
}

abstract class MemberColors {
  static const palette = <MemberAccentColor>[
    MemberAccentColor(
      name: 'Sky Blue',
      hex: '#A8D8EA',
      color: Color(0xFFA8D8EA),
    ),
    MemberAccentColor(
      name: 'Coral Pink',
      hex: '#F4A9A8',
      color: Color(0xFFF4A9A8),
    ),
    MemberAccentColor(
      name: 'Mint Green',
      hex: '#B8E6D0',
      color: Color(0xFFB8E6D0),
    ),
    MemberAccentColor(
      name: 'Lavender',
      hex: '#C5B3E6',
      color: Color(0xFFC5B3E6),
    ),
    MemberAccentColor(
      name: 'Sunny Yellow',
      hex: '#F7E6A1',
      color: Color(0xFFF7E6A1),
    ),
    MemberAccentColor(
      name: 'Peach',
      hex: '#F6C9A0',
      color: Color(0xFFF6C9A0),
    ),
    MemberAccentColor(
      name: 'Sage',
      hex: '#C1D5B0',
      color: Color(0xFFC1D5B0),
    ),
    MemberAccentColor(
      name: 'Rose',
      hex: '#E8B0C9',
      color: Color(0xFFE8B0C9),
    ),
  ];
}
