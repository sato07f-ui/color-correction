import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/models/correction_settings.dart';
import '../features/camera/services/yuv_to_rgba.dart';
import '../features/shader/services/correction_painter.dart';
import '../features/shader/services/correction_shader.dart';

/// issue #3 PoC（方式1）。
///
/// startImageStream で受け取った YUV420 のフレームを CPU で RGBA に変換し、
/// ui.Image にしてから FragmentShader に渡して描画する。
/// 画面上に解像度・fps・処理時間を出し、方式の良し悪しを実機で判断できるようにする。
/// issue #20 からは本番用の補正シェーダー（CorrectionPainter）で描き、
/// タイプと強度を変えて補正の効果を実機で確かめられるようにしている。
class CameraStreamPocPage extends StatefulWidget {
  const CameraStreamPocPage({super.key});

  @override
  State<CameraStreamPocPage> createState() => _CameraStreamPocPageState();
}

class _CameraStreamPocPageState extends State<CameraStreamPocPage>
    with WidgetsBindingObserver {
  static const _presets = [
    ResolutionPreset.low,
    ResolutionPreset.medium,
    ResolutionPreset.high,
  ];

  CameraController? _controller;
  CorrectionShader? _shader;
  ui.Image? _image;
  int _quarterTurns = 0;
  int _presetIndex = 1;
  var _settings = const CorrectionSettings();
  String? _error;

  // 前のフレームの処理中に届いたフレームは捨てる（溜めると遅延が増える）
  bool _busy = false;

  final _fpsWatch = Stopwatch();
  int _framesInWindow = 0;
  int _droppedInWindow = 0;
  double _fps = 0;
  double _dropPerSec = 0;
  double _convertMs = 0;
  double _uploadMs = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _runCameraTask(_start);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SystemChrome.setPreferredOrientations([]);
    _runCameraTask(_stopCamera);
    _image?.dispose();
    super.dispose();
  }

  // カメラの起動と停止は、重ならないように1つずつ順番に実行する。
  // 初期化の途中で停止すると、プラグインの中で例外が出てカメラが映らなくなる。
  Future<void> _cameraTask = Future.value();

  void _runCameraTask(Future<void> Function() task) {
    _cameraTask = _cameraTask.then((_) => task());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // inactive では止めない。権限ダイアログを出しただけでも inactive になるため。
    if (state == AppLifecycleState.paused) {
      _runCameraTask(_stopCamera);
    } else if (state == AppLifecycleState.resumed) {
      _runCameraTask(_start);
    }
  }

  Future<void> _start() async {
    if (_controller != null) return;
    try {
      _shader ??= await CorrectionShader.load();

      final cameras = await availableCameras();
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        _presets[_presetIndex],
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      _controller = controller;
      await controller.initialize();
      // 縦持ち固定なので、センサーの向きだけ回せば正しい向きになる
      _quarterTurns = back.sensorOrientation ~/ 90;
      _fpsWatch
        ..reset()
        ..start();
      await controller.startImageStream(_onFrame);
      if (mounted) setState(() => _error = null);
    } catch (e) {
      // 失敗したら片付けておき、次にアプリに戻ったとき（resumed）にやり直せるようにする
      await _stopCamera();
      final message = e is CameraException
          ? '${e.code}: ${e.description}'
          : '$e';
      if (mounted) setState(() => _error = message);
    }
  }

  Future<void> _stopCamera() async {
    final controller = _controller;
    _controller = null;
    _busy = false;
    if (controller == null) return;
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    await controller.dispose();
  }

  void _switchResolution() {
    _runCameraTask(() async {
      await _stopCamera();
      if (!mounted) return;
      setState(() => _presetIndex = (_presetIndex + 1) % _presets.length);
      await _start();
    });
  }

  void _onFrame(CameraImage frame) {
    if (_busy) {
      _droppedInWindow++;
      return;
    }
    _busy = true;

    final watch = Stopwatch()..start();
    final Uint8List rgba;
    try {
      rgba = yuv420ToRgba(
        width: frame.width,
        height: frame.height,
        yPlane: frame.planes[0].bytes,
        yRowStride: frame.planes[0].bytesPerRow,
        uPlane: frame.planes[1].bytes,
        vPlane: frame.planes[2].bytes,
        uvRowStride: frame.planes[1].bytesPerRow,
        uvPixelStride: frame.planes[1].bytesPerPixel ?? 1,
      );
    } catch (e) {
      _busy = false;
      rethrow;
    }
    final convertMs = watch.elapsedMicroseconds / 1000;
    watch.reset();

    ui.decodeImageFromPixels(
      rgba,
      frame.width,
      frame.height,
      ui.PixelFormat.rgba8888,
      (image) {
        _busy = false;
        if (!mounted || _controller == null) {
          image.dispose();
          return;
        }
        final old = _image;
        setState(() {
          _image = image;
          _convertMs = _smooth(_convertMs, convertMs);
          _uploadMs = _smooth(_uploadMs, watch.elapsedMicroseconds / 1000);
          _countFrame();
        });
        old?.dispose();
      },
    );
  }

  double _smooth(double prev, double next) =>
      prev == 0 ? next : prev * 0.9 + next * 0.1;

  void _countFrame() {
    _framesInWindow++;
    final elapsed = _fpsWatch.elapsedMilliseconds;
    if (elapsed >= 1000) {
      _fps = _framesInWindow * 1000 / elapsed;
      _dropPerSec = _droppedInWindow * 1000 / elapsed;
      _framesInWindow = 0;
      _droppedInWindow = 0;
      _fpsWatch
        ..reset()
        ..start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    final shader = _shader;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null && shader != null)
            CustomPaint(
              painter: CorrectionPainter(
                shader: shader,
                image: image,
                settings: _settings,
                quarterTurns: _quarterTurns,
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Stats(
                    lines: [
                      if (_error != null) 'エラー: $_error',
                      if (image != null)
                        '解像度: ${image.width}x${image.height}'
                            '（${_presets[_presetIndex].name}）',
                      '表示: ${_fps.toStringAsFixed(1)} fps'
                          '（捨てたフレーム ${_dropPerSec.toStringAsFixed(1)}/秒）',
                      'YUV→RGBA: ${_convertMs.toStringAsFixed(1)} ms',
                      'ui.Image 生成: ${_uploadMs.toStringAsFixed(1)} ms',
                    ],
                  ),
                  const Spacer(),
                  _CorrectionControls(
                    settings: _settings,
                    onChanged: (settings) =>
                        setState(() => _settings = settings),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _switchResolution,
                    child: const Text('解像度を切り替え'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 補正タイプと強度を変える操作部品（PoC 用の簡易版）。
class _CorrectionControls extends StatelessWidget {
  const _CorrectionControls({required this.settings, required this.onChanged});

  final CorrectionSettings settings;
  final ValueChanged<CorrectionSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<CorrectionType>(
              segments: [
                for (final type in CorrectionType.values)
                  ButtonSegment(value: type, label: Text(type.displayName)),
              ],
              selected: {settings.type},
              onSelectionChanged: (selected) =>
                  onChanged(settings.copyWith(type: selected.first)),
              style: SegmentedButton.styleFrom(
                foregroundColor: Colors.white,
                selectedForegroundColor: Colors.black,
                selectedBackgroundColor: Colors.white,
              ),
            ),
            Row(
              children: [
                Text(
                  '強度 ${(settings.strength * 100).round()}%',
                  style: const TextStyle(color: Colors.white),
                ),
                Expanded(
                  child: Slider(
                    value: settings.strength,
                    onChanged: (strength) =>
                        onChanged(settings.copyWith(strength: strength)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(
          lines.join('\n'),
          style: const TextStyle(color: Colors.white, fontSize: 13),
        ),
      ),
    );
  }
}
