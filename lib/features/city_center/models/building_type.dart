import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Şehir Merkezi Bina Türü Tanımı (Footprint, Renk ve Görsel Özellikler)
class BuildingType {
  final String name;
  final int footprintCols;
  final int footprintRows;
  final Color wallColor;
  final Color roofColor;
  final double wallHeight;
  final String? assetPath;
  final Sprite? sprite;

  const BuildingType({
    required this.name,
    required this.footprintCols,
    required this.footprintRows,
    this.wallColor = const Color(0xFF2C3E50),
    this.roofColor = const Color(0xFFE2B755),
    this.wallHeight = 28.0,
    this.assetPath,
    this.sprite,
  });

  BuildingType copyWith({
    String? name,
    int? footprintCols,
    int? footprintRows,
    Color? wallColor,
    Color? roofColor,
    double? wallHeight,
    String? assetPath,
    Sprite? sprite,
  }) {
    return BuildingType(
      name: name ?? this.name,
      footprintCols: footprintCols ?? this.footprintCols,
      footprintRows: footprintRows ?? this.footprintRows,
      wallColor: wallColor ?? this.wallColor,
      roofColor: roofColor ?? this.roofColor,
      wallHeight: wallHeight ?? this.wallHeight,
      assetPath: assetPath ?? this.assetPath,
      sprite: sprite ?? this.sprite,
    );
  }
}
