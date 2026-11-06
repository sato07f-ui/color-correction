import 'package:color_correction/color/basic_color.dart';
import 'package:color_correction/color/color_math.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rgbToLab', () {
    test('白は L=100, a=b=0', () {
      final lab = rgbToLab(255, 255, 255);
      expect(lab.l, closeTo(100, 0.01));
      expect(lab.a, closeTo(0, 0.01));
      expect(lab.b, closeTo(0, 0.01));
    });

    test('黒は L=0', () {
      final lab = rgbToLab(0, 0, 0);
      expect(lab.l, closeTo(0, 0.01));
    });

    test('赤 (255,0,0)', () {
      final lab = rgbToLab(255, 0, 0);
      expect(lab.l, closeTo(53.24, 0.01));
      expect(lab.a, closeTo(80.09, 0.01));
      expect(lab.b, closeTo(67.20, 0.01));
    });

    test('青 (0,0,255)', () {
      final lab = rgbToLab(0, 0, 255);
      expect(lab.l, closeTo(32.30, 0.01));
      expect(lab.a, closeTo(79.19, 0.01));
      expect(lab.b, closeTo(-107.86, 0.01));
    });

    test('とき色 #F9A1D0 (249,161,208)', () {
      final lab = rgbToLab(249, 161, 208);
      expect(lab.l, closeTo(76.18, 0.01));
      expect(lab.a, closeTo(39.06, 0.01));
      expect(lab.b, closeTo(-10.34, 0.01));
    });
  });

  // Sharma, Wu, Dalal (2005) の公開テストデータより
  group('ciede2000 (Sharma 公開テストデータ)', () {
    final cases = <List<double>>[
      [50.0, 2.6772, -79.7751, 50.0, 0.0, -82.7485, 2.0425],
      [50.0, 3.1571, -77.2803, 50.0, 0.0, -82.7485, 2.8615],
      [50.0, 2.5, 0.0, 50.0, 0.0, -2.5, 4.3065],
      [50.0, 2.5, 0.0, 50.0, 3.2592, 0.3350, 1.0000],
      [50.0, 2.5, 0.0, 73.0, 25.0, -18.0, 27.1492],
      [50.0, 2.5, 0.0, 61.0, -5.0, 29.0, 22.8977],
      [50.0, 2.5, 0.0, 56.0, -27.0, -3.0, 31.9030],
      [50.0, 2.5, 0.0, 58.0, 24.0, 15.0, 19.4535],
    ];
    for (var i = 0; i < cases.length; i++) {
      final c = cases[i];
      test('ケース${i + 1}', () {
        final d = ciede2000(Lab(c[0], c[1], c[2]), Lab(c[3], c[4], c[5]));
        expect(d, closeTo(c[6], 0.001));
      });
    }

    test('同じ色の差は 0', () {
      const lab = Lab(60, 20, -30);
      expect(ciede2000(lab, lab), closeTo(0, 1e-9));
    });
  });

  group('classifyBasicColor（チーム独自の規則）', () {
    String of(int r, int g, int b) => classifyBasicColor(rgbToLab(r, g, b));

    test('無彩色', () {
      expect(of(255, 255, 255), '白');
      expect(of(0, 0, 0), '黒');
      expect(of(128, 128, 128), '灰色');
    });

    test('有彩色', () {
      expect(of(255, 0, 0), '赤');
      expect(of(255, 128, 0), '黄赤');
      expect(of(255, 255, 0), '黄');
      expect(of(150, 200, 0), '黄緑');
      expect(of(0, 160, 0), '緑');
      expect(of(0, 160, 160), '青緑');
      expect(of(0, 128, 255), '青');
      expect(of(80, 0, 200), '青紫');
      expect(of(128, 0, 128), '紫');
      expect(of(200, 0, 110), '赤紫');
    });
  });
}
