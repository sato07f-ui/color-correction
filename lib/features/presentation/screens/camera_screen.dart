import 'package:flutter/material.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // RGBスライダー値
  double _red = 120;
  double _green = 200;
  double _blue = 70;

  // HSLスライダー値
  double _hue = 180;
  double _saturation = 50;
  double _lightness = 50;

  // FRAME設定
  String _selectedShape = '正方形';
  String _selectedSize = '中';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 上部: 選択した色 & 色コード/名前表示
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey.shade100,
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color.fromRGBO(_red.toInt(), _green.toInt(), _blue.toInt(), 1),
                  border: Border.all(color: Colors.black26),
                  borderRadius: BorderRadius.circular(8),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const Text('選択した色 / リアルタイム', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ],
          ),
        ),

        // 中央: カメラプレビューエリア
        Expanded(
          flex: 4,
          child: Container(
            width: double.infinity,
            color: Colors.black87,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_outlined, color: Colors.white54, size: 64),
                    SizedBox(height: 8),
                    Text('カメラプレビュー（リアルタイム）', style: TextStyle(color: Colors.white70)),
                  ],
                ),
                // 中央の検知フレーム
                Container(
                  width: _selectedSize == '小' ? 70 : (_selectedSize == '中' ? 110 : 150),
                  height: _selectedSize == '小' ? 70 : (_selectedSize == '中' ? 110 : 150),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                    shape: _selectedShape == '円' ? BoxShape.circle : BoxShape.rectangle,
                    borderRadius: _selectedShape == '正方形' ? BorderRadius.circular(8) : null,
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
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, -2))],
            ),
            child: Column(
              children: [
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.blue,
                  unselectedLabelColor: Colors.black54,
                  indicatorColor: Colors.blue,
                  tabs: const [
                    Tab(text: 'RGB'),
                    Tab(text: 'HSL'),
                    Tab(text: 'FRAME'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRgbTab(),
                      _buildHslTab(),
                      _buildFrameTab(),
                    ],
                  ),
                ),
                // リセット & 決定ボタン
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  // RGB調整タブ
  Widget _buildRgbTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _buildSliderRow('Red', _red, 0, 255, Colors.red, (v) => setState(() => _red = v)),
        _buildSliderRow('Green', _green, 0, 255, Colors.green, (v) => setState(() => _green = v)),
        _buildSliderRow('Blue', _blue, 0, 255, Colors.blue, (v) => setState(() => _blue = v)),
      ],
    );
  }

  // HSL調整タブ
  Widget _buildHslTab() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        _buildSliderRow('H (色相)', _hue, 0, 360, Colors.purple, (v) => setState(() => _hue = v)),
        _buildSliderRow('S (彩度)', _saturation, 0, 100, Colors.orange, (v) => setState(() => _saturation = v)),
        _buildSliderRow('L (輝度)', _lightness, 0, 100, Colors.teal, (v) => setState(() => _lightness = v)),
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
              ButtonSegment(value: '正方形', label: Text('正方形'), icon: Icon(Icons.crop_square)),
              ButtonSegment(value: '円', label: Text('円'), icon: Icon(Icons.circle_outlined)),
              ButtonSegment(value: '長方形', label: Text('長方形'), icon: Icon(Icons.rectangle_outlined)),
            ],
            selected: {_selectedShape},
            onSelectionChanged: (val) => setState(() => _selectedShape = val.first),
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
            onSelectionChanged: (val) => setState(() => _selectedSize = val.first),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow(String label, double value, double min, double max, Color activeColor, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 70, child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
        Expanded(
          child: Slider(
            value: value,
            min: min,
            max: max,
            activeColor: activeColor,
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 40, child: Text(value.toInt().toString(), textAlign: TextAlign.right)),
      ],
    );
  }
}