import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../color/color_names.dart';
import '../../../core/models/correction_settings.dart';
import '../../../core/providers/correction_settings_provider.dart';
import '../../camera/services/camera_stream_service.dart';
import '../../camera/services/color_sampler.dart';
import '../../shader/services/correction_painter.dart';
import '../../shader/services/correction_shader.dart';

class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen>
    with WidgetsBindingObserver {
  late final CameraStreamService _cameraService;
  CorrectionShader? _shader;
  ui.Image? _image;
  String? _cameraError;
  String? _colorSampleError;
  String? _colorNameError;
  ColorNameResult? _colorName;
  bool _isSampling = false;
  int _sampleRequest = 0;
  bool _cameraPermissionDenied = false;
  bool _permissionDialogShown = false;
  bool _isStarting = true;
  Future<void>? _initialization;
  final ColorSampler _colorSampler = const ColorSampler();

  // RGBスライダー値
  double _red = 120;
  double _green = 200;
  double _blue = 70;

  // FRAME設定
  String _selectedShape = '正方形';
  String _selectedSize = '中';

  // 色名カード
  bool _showColorNameCard = false;
  ColorNameResult? _colorNameResult;
  JisColor? _representativeColor;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cameraService = CameraStreamService(
      onImage: _onImage,
      onError: _onCameraError,
    );
    unawaited(_loadColorNames());
    _initializeCamera();
  }

  Future<void> _loadColorNames() async {
    try {
      if (!ColorNames.isLoaded) {
        await ColorNames.load();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _colorNameError = '色名データの読み込みに失敗しました: $error');
    }
  }

  Future<void> _initializeCamera() async {
    final runningInitialization = _initialization;
    if (runningInitialization != null) {
      await runningInitialization;
      return;
    }

    final initialization = _initializeCameraInternal();
    _initialization = initialization;
    try {
      await initialization;
    } finally {
      if (identical(_initialization, initialization)) {
        _initialization = null;
      }
    }
  }

  Future<void> _initializeCameraInternal() async {
    try {
      if (_shader == null) {
        final shader = await CorrectionShader.load();
        if (!mounted) {
          shader.dispose();
          return;
        }
        _shader = shader;
      }
      await _cameraService.start();
    } catch (error) {
      _onCameraError(error);
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  void _onImage(ui.Image image) {
    if (!mounted) {
      image.dispose();
      return;
    }
    final oldImage = _image;
    setState(() {
      _image = image;
      _cameraError = null;
      _cameraPermissionDenied = false;
    });
    oldImage?.dispose();
    unawaited(_sampleImage(image));
  }

  Future<void> _sampleImage(ui.Image image) async {
    if (_isSampling) return;
    _isSampling = true;
    final request = ++_sampleRequest;
    try {
      final sampled = await _colorSampler.sampleCenter(image);
      if (!mounted || request != _sampleRequest || !identical(_image, image)) {
        return;
      }
      if (sampled == null) {
        throw StateError('カメラ画像から色を取得できませんでした');
      }

      ColorNameResult? colorName;
      if (ColorNames.isLoaded) {
        colorName = findColorName(sampled.r, sampled.g, sampled.b);
      }
      setState(() {
        _red = sampled.r.toDouble();
        _green = sampled.g.toDouble();
        _blue = sampled.b.toDouble();
        _colorName = colorName;
        _colorSampleError = null;
      });
    } catch (error) {
      if (mounted && request == _sampleRequest) {
        setState(() => _colorSampleError = '色の取得に失敗しました: $error');
      }
    } finally {
      _isSampling = false;
    }
  }

  void _onCameraError(Object error) {
    if (!mounted) return;
    final permissionDenied = _isCameraPermissionDenied(error);
    setState(() {
      _cameraError = _cameraErrorMessage(error);
      _cameraPermissionDenied = permissionDenied;
    });
    if (permissionDenied) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPermissionDialog();
      });
    }
  }

  bool _isCameraPermissionDenied(Object error) {
    if (error is! CameraException) return false;
    return error.code == 'CameraAccessDenied' ||
        error.code == 'CameraAccessDeniedWithoutPrompt' ||
        error.code == 'CameraAccessRestricted';
  }

  String _cameraErrorMessage(Object error) {
    if (error is CameraException) {
      if (_isCameraPermissionDenied(error)) {
        return 'カメラの使用が許可されていません。\n設定からカメラへのアクセスを許可してください。';
      }
      return '${error.code}: ${error.description ?? 'カメラを利用できません'}';
    }
    return '$error';
  }

  Future<void> _openCameraSettings() async {
    _permissionDialogShown = false;
    final opened = await openAppSettings();
    if (!opened && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('設定画面を開けませんでした')));
    }
  }

  Future<void> _showPermissionDialog() async {
    if (!mounted || !_cameraPermissionDenied || _permissionDialogShown) {
      return;
    }
    _permissionDialogShown = true;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('カメラの許可が必要です'),
        content: const Text(
          'カメラ映像を表示するには、カメラへのアクセスを許可してください。\n'
          '設定画面からカメラの権限を変更できます。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('あとで'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _openCameraSettings();
            },
            child: const Text('設定を開く'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _cameraService.stop();
    } else if (state == AppLifecycleState.resumed) {
      _isStarting = true;
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sampleRequest++;
    _cameraService.stop();
    _image?.dispose();
    _shader?.dispose();
    super.dispose();
  }

  void _closeColorNameCard() {
    setState(() {
      _showColorNameCard = false;
    });
  }

  void _openColorNameCard() {
    final result = findColorName(_red.toInt(), _green.toInt(), _blue.toInt());

    JisColor? representative;

    if (result.common != null) {
      for (final color in ColorNames.colors) {
        if (result.common == color.name ||
            result.common!.startsWith('${color.name}に')) {
          representative = color;
          break;
        }
      }
    }

    setState(() {
      _colorNameResult = result;
      _representativeColor = representative;
      _showColorNameCard = true;
    });
  }

  Widget _buildColorNameCard() {
    final result = _colorNameResult;
    if (result == null) {
      return const SizedBox.shrink();
    }

    final representative = _representativeColor;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'COLOR NAME',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _closeColorNameCard,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('基本色名'),
              Text(
                result.basic,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              const Text('慣用色名'),
              Text(
                result.common ?? '該当なし',
                style: const TextStyle(fontSize: 20),
              ),
              if (representative != null) ...[
                const SizedBox(height: 16),
                const Text('代表色'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(
                          representative.r,
                          representative.g,
                          representative.b,
                          1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.black12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        representative.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _buildMainContent(),
        if (_showColorNameCard)
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeColorNameCard,
              child: Container(
                color: Colors.black54,
                child: Center(
                  child: GestureDetector(
                    onTap: () {},
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.7, end: 1.0),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutBack,
                      builder: (context, scale, child) {
                        return Transform.scale(scale: scale, child: child);
                      },
                      child: _buildColorNameCard(),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // 色名カードの下に表示する、カメラ画面の本体
  Widget _buildMainContent() {
    return Column(
      children: [
        // 上部: 選択した色 & 色コード/名前表示
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              GestureDetector(
                onTap: _openColorNameCard,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Color.fromRGBO(
                      _red.toInt(),
                      _green.toInt(),
                      _blue.toInt(),
                      1,
                    ),
                    border: Border.all(color: Colors.black26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${_red.toInt().toRadixString(16).padLeft(2, '0').toUpperCase()}'
                    '${_green.toInt().toRadixString(16).padLeft(2, '0').toUpperCase()}'
                    '${_blue.toInt().toRadixString(16).padLeft(2, '0').toUpperCase()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Text(
                    '選択した色 / リアルタイム',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 補正タイプ選択UI
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Consumer(
            builder: (context, ref, child) {
              final settings = ref.watch(correctionSettingsProvider);

              return Row(
                children: CorrectionType.values.map((type) {
                  final isSelected = settings.type == type;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: OutlinedButton(
                        onPressed: () {
                          ref
                              .read(correctionSettingsProvider.notifier)
                              .setType(type);
                        },
                        style: OutlinedButton.styleFrom(
                          backgroundColor: isSelected
                              ? Colors.blue.withValues(alpha: 0.15)
                              : Colors.white,
                          foregroundColor: Colors.blue,
                          side: BorderSide(
                            color: isSelected ? Colors.blue : Colors.grey,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (isSelected) const Icon(Icons.check, size: 16),
                            if (isSelected) const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                type.displayName,
                                style: TextStyle(
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ),

        // 中央: カメラプレビューエリア
        Expanded(
          flex: 4,
          child: Container(
            width: double.infinity,
            color: Colors.black,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_image != null && _shader != null)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: CorrectionPainter(
                        shader: _shader!,
                        image: _image!,
                        settings: ref.watch(correctionSettingsProvider),
                        quarterTurns: _cameraService.quarterTurns,
                      ),
                    ),
                  )
                else
                  _buildCameraPlaceholder(),
                // 中央の検知フレーム
                Container(
                  width: _selectedSize == '小'
                      ? 70
                      : (_selectedSize == '中' ? 110 : 150),
                  height: _selectedSize == '小'
                      ? 70
                      : (_selectedSize == '中' ? 110 : 150),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    shape: _selectedShape == '円'
                        ? BoxShape.circle
                        : BoxShape.rectangle,
                    borderRadius: _selectedShape == '正方形'
                        ? BorderRadius.circular(8)
                        : null,
                  ),
                ),
                // HUDカード
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'SELECTED COLOR',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '#${_red.toInt().toRadixString(16).padLeft(2, '0').toUpperCase()}'
                          '${_green.toInt().toRadixString(16).padLeft(2, '0').toUpperCase()}'
                          '${_blue.toInt().toRadixString(16).padLeft(2, '0').toUpperCase()}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_colorName != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _colorName!.common ?? _colorName!.basic,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                        if (_colorSampleError != null)
                          Text(
                            _colorSampleError!,
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 11,
                            ),
                          ),
                        if (_colorNameError != null)
                          Text(
                            _colorNameError!,
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 下部: 色調整エリア（RGB / HSL / FRAME）
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Consumer(
                  builder: (context, ref, child) {
                    final settings = ref.watch(correctionSettingsProvider);

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '補正強度',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text('${(settings.strength * 100).round()}%'),
                            ],
                          ),
                          Slider(
                            value: settings.strength,
                            min: 0,
                            max: 1,
                            onChanged: (value) {
                              ref
                                  .read(correctionSettingsProvider.notifier)
                                  .setStrength(value);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // 画面が低い端末ではみ出さないよう、スクロールできるようにする
                Expanded(child: SingleChildScrollView(child: _buildFrameTab())),
                // リセット & 決定ボタン
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _red = 120;
                              _green = 200;
                              _blue = 70;
                            });
                          },
                          child: const Text('リセット'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('色調整を適用しました')),
                            );
                          },
                          child: const Text('決定'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraPlaceholder() {
    final message =
        _cameraError ?? (_isStarting ? 'カメラを起動しています...' : 'カメラ映像を取得できません');
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 64),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      ],
    );
  }

  // FRAME設定タブ
  Widget _buildFrameTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('フレームの形', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: '正方形',
                label: Text('正方形'),
                icon: Icon(Icons.crop_square),
              ),
              ButtonSegment(
                value: '円',
                label: Text('円'),
                icon: Icon(Icons.circle_outlined),
              ),
              ButtonSegment(
                value: '長方形',
                label: Text('長方形'),
                icon: Icon(Icons.rectangle_outlined),
              ),
            ],
            selected: {_selectedShape},
            onSelectionChanged: (val) =>
                setState(() => _selectedShape = val.first),
          ),
          const SizedBox(height: 16),
          const Text('フレームの大きさ', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: '小', label: Text('小')),
              ButtonSegment(value: '中', label: Text('中')),
              ButtonSegment(value: '大', label: Text('大')),
            ],
            selected: {_selectedSize},
            onSelectionChanged: (val) =>
                setState(() => _selectedSize = val.first),
          ),
        ],
      ),
    );
  }
}
