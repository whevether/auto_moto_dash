import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Lays [child] (the theme's instrument cluster) out at a fixed size and
/// captures it to a [ui.Image] every [interval] (30 Hz by default) for the
/// cockpit's cluster screen. Place it underneath the 3D view: it must be
/// painted to be captured, but it is never visible.
class ClusterTextureCapture extends StatefulWidget {
  const ClusterTextureCapture({
    super.key,
    required this.child,
    required this.onFrame,
    this.logicalSize = const Size(1200, 500),
    this.pixelRatio = 1,
    this.interval = const Duration(milliseconds: 33),
  });

  final Widget child;

  /// Receives each image; the callee may read it asynchronously and the
  /// capture disposes it once the returned future completes.
  final Future<void> Function(ui.Image image) onFrame;
  final Size logicalSize;
  final double pixelRatio;
  final Duration interval;

  @override
  State<ClusterTextureCapture> createState() => _ClusterTextureCaptureState();
}

class _ClusterTextureCaptureState extends State<ClusterTextureCapture> {
  final GlobalKey _boundary = GlobalKey();
  Timer? _timer;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.interval, (_) => _request());
  }

  @override
  void didUpdateWidget(ClusterTextureCapture old) {
    super.didUpdateWidget(old);
    if (old.interval != widget.interval) {
      _timer?.cancel();
      _timer = Timer.periodic(widget.interval, (_) => _request());
    }
  }

  void _request() {
    if (_busy || !mounted) return;
    _busy = true;
    // Capture right after a frame so the boundary is freshly painted.
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => _capture())
      ..ensureVisualUpdate();
  }

  Future<void> _capture() async {
    try {
      final ro = _boundary.currentContext?.findRenderObject();
      if (!mounted || ro is! RenderRepaintBoundary || !ro.hasSize) return;
      if (kDebugMode && ro.debugNeedsPaint) return;
      final image = await ro.toImage(pixelRatio: widget.pixelRatio);
      if (!mounted) {
        image.dispose();
        return;
      }
      try {
        await widget.onFrame(image);
      } finally {
        image.dispose();
      }
    } catch (_) {
      // A dropped frame is harmless; try again on the next tick.
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.logicalSize;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: size.width,
            maxWidth: size.width,
            minHeight: size.height,
            maxHeight: size.height,
            child: RepaintBoundary(
              key: _boundary,
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(size: size, textScaler: TextScaler.noScaling),
                child: SizedBox.fromSize(size: size, child: widget.child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
