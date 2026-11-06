import 'dart:ui' as ui;

import 'package:camera/camera.dart';

import 'yuv_to_rgba.dart';

typedef CameraImageCallback = void Function(ui.Image image);
typedef CameraErrorCallback = void Function(Object error);

/// カメラの初期化とフレームの RGBA 変換を管理する。
class CameraStreamService {
  CameraStreamService({required this.onImage, required this.onError});

  final CameraImageCallback onImage;
  final CameraErrorCallback onError;

  CameraController? _controller;
  bool _busy = false;
  int _generation = 0;

  int get quarterTurns =>
      (_controller?.description.sensorOrientation ?? 0) ~/ 90;

  Future<void> start() async {
    if (_controller != null) return;

    final generation = ++_generation;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw StateError('利用可能なカメラが見つかりません');
      }

      final camera = cameras.firstWhere(
        (candidate) => candidate.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      _controller = controller;

      await controller.initialize();
      if (generation != _generation) return;
      await controller.startImageStream(_onFrame);
    } catch (error) {
      await stop();
      onError(error);
    }
  }

  Future<void> stop() async {
    ++_generation;
    _busy = false;
    final controller = _controller;
    _controller = null;
    if (controller == null) return;

    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    await controller.dispose();
  }

  void _onFrame(CameraImage frame) {
    if (_busy || _controller == null) return;
    _busy = true;
    final generation = _generation;

    try {
      final rgba = yuv420ToRgba(
        width: frame.width,
        height: frame.height,
        yPlane: frame.planes[0].bytes,
        yRowStride: frame.planes[0].bytesPerRow,
        uPlane: frame.planes[1].bytes,
        vPlane: frame.planes[2].bytes,
        uvRowStride: frame.planes[1].bytesPerRow,
        uvPixelStride: frame.planes[1].bytesPerPixel ?? 1,
      );

      ui.decodeImageFromPixels(
        rgba,
        frame.width,
        frame.height,
        ui.PixelFormat.rgba8888,
        (image) {
          _busy = false;
          if (generation != _generation || _controller == null) {
            image.dispose();
            return;
          }
          onImage(image);
        },
      );
    } catch (error) {
      _busy = false;
      onError(error);
    }
  }
}
