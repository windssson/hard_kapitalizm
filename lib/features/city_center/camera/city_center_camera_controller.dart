import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Şehir Merkezi İzometrik Kamera Kontrolcüsü (Pan, Pinch Zoom ve Sınır Koruması)
class CityCenterCameraController {
  final CameraComponent cameraComp;
  final int gridSize;
  final double tileW;
  final double tileH;

  static const double minZoom = 0.4;
  static const double maxZoom = 2.6;

  CityCenterCameraController({
    required this.cameraComp,
    required this.gridSize,
    required this.tileW,
    required this.tileH,
  });

  /// Ekrandaki (local) dokunma noktasını kamera dünyasındaki koordinata çevirir
  Vector2 screenToWorld(Offset screenPoint) {
    return cameraComp.viewfinder.parentToLocal(Vector2(screenPoint.dx, screenPoint.dy));
  }

  /// Tek parmakla kamerayı kaydırma (Pan)
  void pan(double dx, double dy) {
    final zoom = cameraComp.viewfinder.zoom;
    final currentPos = cameraComp.viewfinder.position;
    final nextX = currentPos.x - (dx / zoom);
    final nextY = currentPos.y - (dy / zoom);
    cameraComp.viewfinder.position = clampPosition(Vector2(nextX, nextY));
  }

  /// 2 parmakla pinch zoom
  void applyPinchZoom(double targetZoom) {
    cameraComp.viewfinder.zoom = targetZoom.clamp(minZoom, maxZoom);
    cameraComp.viewfinder.position = clampPosition(cameraComp.viewfinder.position);
  }

  /// Butonla adım adım zoom yapma
  void zoomByStep(double step) {
    final current = cameraComp.viewfinder.zoom;
    cameraComp.viewfinder.zoom = (current + step).clamp(minZoom, maxZoom);
    cameraComp.viewfinder.position = clampPosition(cameraComp.viewfinder.position);
  }

  /// Haritayı merkeze al
  void centerMap() {
    final centerCol = gridSize / 2;
    final centerRow = gridSize / 2;
    final centerPos = Vector2(0, (centerCol + centerRow) * (tileH / 2));
    cameraComp.viewfinder.position = centerPos;
    cameraComp.viewfinder.zoom = 1.0;
  }

  /// Haritanın dışına sınırsız kaymayı engelleyen sınırlar (Camera Clamping)
  Vector2 clampPosition(Vector2 pos) {
    final halfMapWidth = (gridSize * tileW) / 2 + 800;
    final mapHeight = (gridSize * tileH) + 800;

    final clampedX = pos.x.clamp(-halfMapWidth, halfMapWidth);
    final clampedY = pos.y.clamp(-400.0, mapHeight);
    return Vector2(clampedX, clampedY);
  }
}
