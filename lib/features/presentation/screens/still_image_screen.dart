import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/correction_settings.dart';
import '../../../core/providers/correction_settings_provider.dart';
import '../../shader/services/correction_painter.dart';
import '../../shader/services/correction_shader.dart';

class StillImageScreen extends ConsumerStatefulWidget {
  const StillImageScreen({super.key});

  @override
  ConsumerState<StillImageScreen> createState() => _StillImageScreenState();
}

class _StillImageScreenState extends ConsumerState<StillImageScreen> {
  final ImagePicker _picker = ImagePicker();

  ui.Image? _image;
  CorrectionShader? _shader;

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadShader();
  }

  // 色補正シェーダーを読み込む
  Future<void> _loadShader() async {
    try {
      final shader = await CorrectionShader.load();

      if (!mounted) {
        shader.dispose();
        return;
      }

      setState(() {
        _shader = shader;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = '補正機能の読み込みに失敗しました: $e';
      });
    }
  }

  // ギャラリーから写真を選択する
  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile == null) return;

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final bytes = await pickedFile.readAsBytes();

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final decodedImage = frame.image;

      codec.dispose();

      if (!mounted) {
        decodedImage.dispose();
        return;
      }

      setState(() {
        _image?.dispose();
        _image = decodedImage;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = '写真の読み込みに失敗しました: $e';
      });
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(correctionSettingsProvider);
    final notifier = ref.read(correctionSettingsProvider.notifier);

    return Column(
      children: [
        // 写真表示エリア
        Expanded(
          flex: 4,
          child: Container(
            width: double.infinity,
            color: Colors.grey.shade200,
            child: _buildImageArea(settings),
          ),
        ),

        // 補正設定エリア
        Expanded(
          flex: 5,
          child: Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '写真補正パネル',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),

                const SizedBox(height: 8),

                // 補正タイプ選択
                const Text('補正タイプ'),

                const SizedBox(height: 12),

                SegmentedButton<CorrectionType>(
                  segments: CorrectionType.values.map((type) {
                    return ButtonSegment<CorrectionType>(
                      value: type,
                      label: Text(type.displayName),
                    );
                  }).toList(),
                  selected: {settings.type},
                  onSelectionChanged: (selected) {
                    notifier.setType(selected.first);
                  },
                ),

                const SizedBox(height: 12),

                // 補正強度
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('補正強度'),
                    Text(
                      '${(settings.strength * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),

                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    overlayShape: SliderComponentShape.noOverlay,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 7,
                    ),
                  ),
                  child: Slider(
                    value: settings.strength,
                    min: 0,
                    max: 1,
                    divisions: 100,
                    onChanged: (value) {
                      notifier.setStrength(value);
                    },
                  ),
                ),

                const Spacer(),

                // 写真選択ボタン
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _pickImage,
                  icon: const Icon(Icons.photo_library),
                  label: Text(_image == null ? 'ギャラリーから選ぶ' : '別の写真を選ぶ'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 写真表示部分
  Widget _buildImageArea(CorrectionSettings settings) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    if (_image == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 12),
            Text('写真を選択してください', style: TextStyle(color: Colors.black54)),
          ],
        ),
      );
    }

    if (_shader == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return CustomPaint(
      painter: CorrectionPainter(
        shader: _shader!,
        image: _image!,
        settings: settings,
      ),
      child: const SizedBox.expand(),
    );
  }
}
