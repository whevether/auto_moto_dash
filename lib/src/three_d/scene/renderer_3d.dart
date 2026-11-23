import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'scene_model.dart';

/// Rendering budget.
enum RenderQuality {
  /// No shadows, reduced resolution, less traffic and scenery.
  low,
  medium,

  /// Shadows, full resolution and anti-aliasing.
  high;

  String get label => switch (this) {
    RenderQuality.low => '低',
    RenderQuality.medium => '中',
    RenderQuality.high => '高',
  };
}

/// A backend that draws a [SceneModel]: flutter_scene on native platforms,
/// three.js on the web.
abstract class Renderer3D {
  /// Human-readable backend name (shown in diagnostics).
  String get backendName;

  /// Creates GPU resources for every mesh, material, node and light.
  /// Throws when the platform cannot render (e.g. Flutter GPU disabled).
  Future<void> attach(SceneModel model, RenderQuality quality);

  /// Applies [frame]'s changes; the view presents them on its next paint.
  void render(SceneFrame frame);

  /// Replaces the texture bound to materials whose `textureSlot` is [slot].
  /// The renderer may read [image] asynchronously but never disposes it.
  Future<void> updateTexture(String slot, ui.Image image);

  /// The widget presenting the rendered scene.
  Widget buildView(BuildContext context);

  void dispose();
}
