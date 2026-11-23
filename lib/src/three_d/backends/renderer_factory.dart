import '../scene/renderer_3d.dart';
import 'renderer_factory_native.dart'
    if (dart.library.js_interop) 'renderer_factory_web.dart'
    as impl;

/// Creates the platform backend: three.js on the web, flutter_scene
/// (Flutter GPU) everywhere else.
Renderer3D createRenderer3D() => impl.createPlatformRenderer();
