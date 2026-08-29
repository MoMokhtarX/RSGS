import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class DeterministicColor {
  static (Color, Color) getColor(String input) {
    if (input.isEmpty) return (AppColors.avatarBackgrounds[0], AppColors.avatarTexts[0]);
    
    int hash = 0;
    for (int i = 0; i < input.length; i++) {
      hash = input.codeUnitAt(i) + ((hash << 5) - hash);
    }
    
    final index = hash.abs() % AppColors.avatarBackgrounds.length;
    return (AppColors.avatarBackgrounds[index], AppColors.avatarTexts[index]);
  }
}
