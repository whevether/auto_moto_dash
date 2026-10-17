import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// 图片相关的工具类
class ImageUtils {
  /// Disposes every successful decode if any image in a batch fails.
  static Future<List<ui.Image>> getImages(List<String> assets) =>
      Future.wait(assets.map(getImage), cleanUp: (image) => image.dispose());

  /// 绘制时需要用到 ui.Image 的对象，通过此方法进行转换
  static Future<ui.Image> getImage(String asset) async {
    final ByteData data = await rootBundle.load(
      "packages/auto_moto_dash/$asset",
    );
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }
}
