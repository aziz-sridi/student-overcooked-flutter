import 'package:flutter/material.dart';

class QuickStatItem {
  const QuickStatItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
}
