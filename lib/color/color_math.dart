// RGB -> CIE L*a*b* 変換と CIEDE2000 色差。
// Flutter に依存しない純粋な Dart なので、`flutter test` だけで検証できる。
import 'dart:math' as math;

class Lab {
  final double l;
  final double a;
  final double b;
  const Lab(this.l, this.a, this.b);

  @override
  String toString() => 'Lab($l, $a, $b)';
}

double _linear(int c) {
  final v = c / 255.0;
  return v <= 0.04045
      ? v / 12.92
      : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}

double _f(double t) {
  const d = 6 / 29;
  return t > d * d * d
      ? math.pow(t, 1 / 3).toDouble()
      : t / (3 * d * d) + 4 / 29;
}

/// sRGB（各 0〜255）を CIE L*a*b*（D65）に変換する。
Lab rgbToLab(int r, int g, int b) {
  final rl = _linear(r);
  final gl = _linear(g);
  final bl = _linear(b);
  final x = 0.4124564 * rl + 0.3575761 * gl + 0.1804375 * bl;
  final y = 0.2126729 * rl + 0.7151522 * gl + 0.0721750 * bl;
  final z = 0.0193339 * rl + 0.1191920 * gl + 0.9503041 * bl;
  final fx = _f(x / 0.95047);
  final fy = _f(y / 1.0);
  final fz = _f(z / 1.08883);
  return Lab(116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz));
}

double _rad(double deg) => deg * math.pi / 180;
double _deg(double rad) => rad * 180 / math.pi;

/// CIEDE2000 色差（ΔE00）。値が小さいほど近い色。
double ciede2000(Lab c1, Lab c2) {
  final cBar = (math.sqrt(c1.a * c1.a + c1.b * c1.b) +
          math.sqrt(c2.a * c2.a + c2.b * c2.b)) /
      2;
  final cBar7 = math.pow(cBar, 7).toDouble();
  final g = 0.5 * (1 - math.sqrt(cBar7 / (cBar7 + math.pow(25, 7))));
  final a1p = (1 + g) * c1.a;
  final a2p = (1 + g) * c2.a;
  final c1p = math.sqrt(a1p * a1p + c1.b * c1.b);
  final c2p = math.sqrt(a2p * a2p + c2.b * c2.b);

  double hue(double b, double ap) {
    if (b == 0 && ap == 0) return 0;
    final h = _deg(math.atan2(b, ap));
    return h < 0 ? h + 360 : h;
  }

  final h1p = hue(c1.b, a1p);
  final h2p = hue(c2.b, a2p);

  final dLp = c2.l - c1.l;
  final dCp = c2p - c1p;

  double dhp;
  if (c1p * c2p == 0) {
    dhp = 0;
  } else {
    dhp = h2p - h1p;
    if (dhp > 180) {
      dhp -= 360;
    } else if (dhp < -180) {
      dhp += 360;
    }
  }
  final dHp = 2 * math.sqrt(c1p * c2p) * math.sin(_rad(dhp / 2));

  final lBarP = (c1.l + c2.l) / 2;
  final cBarP = (c1p + c2p) / 2;

  double hBarP;
  if (c1p * c2p == 0) {
    hBarP = h1p + h2p;
  } else if ((h1p - h2p).abs() <= 180) {
    hBarP = (h1p + h2p) / 2;
  } else if (h1p + h2p < 360) {
    hBarP = (h1p + h2p + 360) / 2;
  } else {
    hBarP = (h1p + h2p - 360) / 2;
  }

  final t = 1 -
      0.17 * math.cos(_rad(hBarP - 30)) +
      0.24 * math.cos(_rad(2 * hBarP)) +
      0.32 * math.cos(_rad(3 * hBarP + 6)) -
      0.20 * math.cos(_rad(4 * hBarP - 63));

  final dTheta = 30 * math.exp(-math.pow((hBarP - 275) / 25, 2));
  final cBarP7 = math.pow(cBarP, 7).toDouble();
  final rC = 2 * math.sqrt(cBarP7 / (cBarP7 + math.pow(25, 7)));
  final sL = 1 +
      0.015 * math.pow(lBarP - 50, 2) / math.sqrt(20 + math.pow(lBarP - 50, 2));
  final sC = 1 + 0.045 * cBarP;
  final sH = 1 + 0.015 * cBarP * t;
  final rT = -math.sin(_rad(2 * dTheta)) * rC;

  final lTerm = dLp / sL;
  final cTerm = dCp / sC;
  final hTerm = dHp / sH;
  return math.sqrt(lTerm * lTerm + cTerm * cTerm + hTerm * hTerm +
      rT * cTerm * hTerm);
}
