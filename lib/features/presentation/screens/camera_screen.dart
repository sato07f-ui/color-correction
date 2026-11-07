import 'dart:async';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../color/color_names.dart';
import '../../../core/models/correction_settings.dart';
import '../../../core/providers/correction_settings_provider.dart';
import '../../../theme/app_theme.dart';
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

  // 照準の位置の色（カメラ映像から取得する）
  double _red = 120;
  double _green = 200;
  double _blue = 70;

  // 長押ししている間だけ、補正前の映像を表示する
  bool _showOriginal = false;

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

  // 色名カードの下に表示する、カメラ画面の本体。
  // カメラ映像を全面に出し、操作部品は半透明のカードで映像の上に重ねる（F-01、F-07）
  Widget _buildMainContent() {
    final settings = ref.watch(correctionSettingsProvider);

    return GestureDetector(
      onLongPressStart: (_) => setState(() => _showOriginal = true),
      onLongPressEnd: (_) => setState(() => _showOriginal = false),
      onLongPressCancel: () => setState(() => _showOriginal = false),
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_image != null && _shader != null)
              CustomPaint(
                painter: CorrectionPainter(
                  shader: _shader!,
                  image: _image!,
                  // 長押し中は強度 0（補正前の映像）で描く
                  settings: _showOriginal
                      ? settings.copyWith(strength: 0)
                      : settings,
                  quarterTurns: _cameraService.quarterTurns,
                ),
              )
            else
              _buildCameraPlaceholder(),
            // 照準と、照準の位置の色のチップ（F-05）
            Center(child: _buildReticle()),
            // 操作部品は暗い半透明のカードに載せるので、ダークテーマの部品を使う
            Theme(
              data: AppTheme.dark,
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Colors.white),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        _buildTypeSelector(settings),
                        if (_showOriginal) ...[
                          const SizedBox(height: 12),
                          _buildGlassCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            child: const Text(
                              '補正前の映像',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        const Spacer(),
                        _buildBottomPanel(settings),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 映像の上に重ねる、暗い半透明のカード
  Widget _buildGlassCard({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: child,
    );
  }

  // 補正タイプ選択UI
  Widget _buildTypeSelector(CorrectionSettings settings) {
    final primary = AppTheme.dark.colorScheme.primary;

    return _buildGlassCard(
      padding: const EdgeInsets.all(6),
      child: Row(
        children: CorrectionType.values.map((type) {
          final isSelected = settings.type == type;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: OutlinedButton(
                onPressed: () {
                  ref.read(correctionSettingsProvider.notifier).setType(type);
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor: isSelected
                      ? primary.withValues(alpha: 0.35)
                      : Colors.transparent,
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: isSelected ? primary : Colors.white38,
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
      ),
    );
  }

  // 照準と、その下の色のチップ。
  // 照準が画面のちょうど中央に来るよう、チップと同じ高さの余白を上にも入れる
  Widget _buildReticle() {
    const chipHeight = 44.0;
    const gap = 12.0;
    const size = 110.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: chipHeight + gap),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(height: gap),
        SizedBox(height: chipHeight, child: _buildColorChip()),
      ],
    );
  }

  String get _hexCode =>
      '#${_red.toInt().toRadixString(16).padLeft(2, '0').toUpperCase()}'
      '${_green.toInt().toRadixString(16).padLeft(2, '0').toUpperCase()}'
      '${_blue.toInt().toRadixString(16).padLeft(2, '0').toUpperCase()}';

  // 照準の位置の色を表示するチップ。タップすると色名カードが開く
  Widget _buildColorChip() {
    final error = _colorSampleError ?? _colorNameError;
    final name = _colorName?.common ?? _colorName?.basic;

    return GestureDetector(
      onTap: _openColorNameCard,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        padding: const EdgeInsets.only(left: 6, right: 16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color.fromRGBO(
                  _red.toInt(),
                  _green.toInt(),
                  _blue.toInt(),
                  1,
                ),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                error ?? name ?? _hexCode,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: error != null ? Colors.orangeAccent : Colors.white,
                  fontSize: error != null ? 12 : 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (error == null && name != null) ...[
              const SizedBox(width: 8),
              Text(
                _hexCode,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 下部のカード：補正強度
  Widget _buildBottomPanel(CorrectionSettings settings) {
    return _buildGlassCard(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('補正強度', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('${(settings.strength * 100).round()}%'),
            ],
          ),
          Slider(
            value: settings.strength,
            min: 0,
            max: 1,
            onChanged: (value) {
              ref.read(correctionSettingsProvider.notifier).setStrength(value);
            },
          ),
          const Text(
            '画面を長押ししている間は、補正前の映像を表示します',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
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
}
