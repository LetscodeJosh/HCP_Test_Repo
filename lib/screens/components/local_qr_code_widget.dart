import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Privacy-Preserving Local QR Code Widget (Zero External Network Calls).
///
/// Generates and renders an ISO/IEC 18004 compliant QR code 100% offline on-device
/// so sensitive session tokens, doctor names, and MedRep emails are never transmitted
/// to third-party QR generation servers.
class LocalQrCodeWidget extends StatelessWidget {
  final String data;
  final double size;
  final Color foregroundColor;
  final Color backgroundColor;

  const LocalQrCodeWidget({
    Key? key,
    required this.data,
    this.size = 220,
    this.foregroundColor = const Color(0xFF0B192C),
    this.backgroundColor = Colors.white,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final matrix = _QrEncoder.encode(data);
    return Container(
      width: size,
      height: size,
      color: backgroundColor,
      padding: const EdgeInsets.all(8),
      child: CustomPaint(
        size: Size(size - 16, size - 16),
        painter: _QrPainter(
          matrix: matrix,
          foregroundColor: foregroundColor,
          backgroundColor: backgroundColor,
        ),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  final List<List<bool>> matrix;
  final Color foregroundColor;
  final Color backgroundColor;

  _QrPainter({
    required this.matrix,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Offset.zero & size, bgPaint);

    if (matrix.isEmpty) return;
    final n = matrix.length;
    final cellSize = size.width / n;
    final fgPaint = Paint()
      ..color = foregroundColor
      ..style = PaintingStyle.fill;

    for (int r = 0; r < n; r++) {
      for (int c = 0; c < n; c++) {
        if (matrix[r][c]) {
          canvas.drawRect(
            Rect.fromLTWH(
              c * cellSize,
              r * cellSize,
              cellSize + 0.35,
              cellSize + 0.35,
            ),
            fgPaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) {
    return oldDelegate.matrix != matrix ||
        oldDelegate.foregroundColor != foregroundColor;
  }
}

class _QrVersionSpec {
  final int version;
  final int totalDataCodewords;
  final int ecCodewordsPerBlock;
  final List<int> blockDataSizes;
  final List<int> alignmentCenters;
  final int? versionInfoBits;

  const _QrVersionSpec({
    required this.version,
    required this.totalDataCodewords,
    required this.ecCodewordsPerBlock,
    required this.blockDataSizes,
    required this.alignmentCenters,
    this.versionInfoBits,
  });

  int get dimension => 17 + 4 * version;
  int get maxByteCapacity => totalDataCodewords - (version <= 9 ? 2 : 3);
}

class _QrEncoder {
  // ISO/IEC 18004 Level L Specifications for Versions 1..10
  static const List<_QrVersionSpec> _specs = [
    _QrVersionSpec(
      version: 1,
      totalDataCodewords: 19,
      ecCodewordsPerBlock: 7,
      blockDataSizes: [19],
      alignmentCenters: [],
    ),
    _QrVersionSpec(
      version: 2,
      totalDataCodewords: 34,
      ecCodewordsPerBlock: 10,
      blockDataSizes: [34],
      alignmentCenters: [6, 18],
    ),
    _QrVersionSpec(
      version: 3,
      totalDataCodewords: 55,
      ecCodewordsPerBlock: 15,
      blockDataSizes: [55],
      alignmentCenters: [6, 22],
    ),
    _QrVersionSpec(
      version: 4,
      totalDataCodewords: 80,
      ecCodewordsPerBlock: 20,
      blockDataSizes: [80],
      alignmentCenters: [6, 26],
    ),
    _QrVersionSpec(
      version: 5,
      totalDataCodewords: 108,
      ecCodewordsPerBlock: 26,
      blockDataSizes: [108],
      alignmentCenters: [6, 30],
    ),
    _QrVersionSpec(
      version: 6,
      totalDataCodewords: 136,
      ecCodewordsPerBlock: 18,
      blockDataSizes: [68, 68],
      alignmentCenters: [6, 34],
    ),
    _QrVersionSpec(
      version: 7,
      totalDataCodewords: 156,
      ecCodewordsPerBlock: 20,
      blockDataSizes: [78, 78],
      alignmentCenters: [6, 22, 38],
      versionInfoBits: 0x07C94,
    ),
    _QrVersionSpec(
      version: 8,
      totalDataCodewords: 194,
      ecCodewordsPerBlock: 24,
      blockDataSizes: [97, 97],
      alignmentCenters: [6, 24, 42],
      versionInfoBits: 0x085BC,
    ),
    _QrVersionSpec(
      version: 9,
      totalDataCodewords: 232,
      ecCodewordsPerBlock: 30,
      blockDataSizes: [116, 116],
      alignmentCenters: [6, 26, 46],
      versionInfoBits: 0x09A99,
    ),
    _QrVersionSpec(
      version: 10,
      totalDataCodewords: 274,
      ecCodewordsPerBlock: 18,
      blockDataSizes: [68, 68, 69, 69],
      alignmentCenters: [6, 28, 50],
      versionInfoBits: 0x0A4D3,
    ),
  ];

  static List<List<bool>> encode(String input) {
    Uint8List bytes = Uint8List.fromList(utf8.encode(input));
    if (bytes.length > 271) {
      bytes = bytes.sublist(0, 271);
    }

    final spec = _specs.firstWhere(
      (s) => bytes.length <= s.maxByteCapacity,
      orElse: () => _specs.last,
    );

    // 1. Build bit stream: Byte mode (0100) + character count + payload + terminator + padding
    final List<int> bits = [];
    void appendBits(int val, int length) {
      for (int i = length - 1; i >= 0; i--) {
        bits.add((val >> i) & 1);
      }
    }

    appendBits(0x4, 4); // Byte mode indicator
    appendBits(bytes.length, spec.version <= 9 ? 8 : 16);
    for (final b in bytes) {
      appendBits(b, 8);
    }

    final totalDataBits = spec.totalDataCodewords * 8;
    final terminatorLen = (totalDataBits - bits.length).clamp(0, 4);
    appendBits(0, terminatorLen);

    while (bits.length % 8 != 0) {
      bits.add(0);
    }

    final List<int> dataCodewords = [];
    for (int i = 0; i < bits.length; i += 8) {
      int byteVal = 0;
      for (int b = 0; b < 8; b++) {
        byteVal = (byteVal << 1) | bits[i + b];
      }
      dataCodewords.add(byteVal);
    }

    int padToggle = 0;
    while (dataCodewords.length < spec.totalDataCodewords) {
      dataCodewords.add(padToggle % 2 == 0 ? 0xEC : 0x11);
      padToggle++;
    }

    // 2. Split into blocks and compute Reed-Solomon error correction codewords
    final List<List<int>> dataBlocks = [];
    final List<List<int>> ecBlocks = [];
    int offset = 0;
    for (final bSize in spec.blockDataSizes) {
      final block = dataCodewords.sublist(offset, offset + bSize);
      offset += bSize;
      dataBlocks.add(block);
      ecBlocks.add(_computeReedSolomon(block, spec.ecCodewordsPerBlock));
    }

    // Interleave data blocks and EC blocks
    final List<int> interleaved = [];
    final maxDataBlockLen = spec.blockDataSizes.reduce((a, b) => a > b ? a : b);
    for (int i = 0; i < maxDataBlockLen; i++) {
      for (final b in dataBlocks) {
        if (i < b.length) interleaved.add(b[i]);
      }
    }
    for (int i = 0; i < spec.ecCodewordsPerBlock; i++) {
      for (final ec in ecBlocks) {
        if (i < ec.length) interleaved.add(ec[i]);
      }
    }

    // 3. Construct matrix and function patterns
    final n = spec.dimension;
    final List<List<bool>> modules = List.generate(n, (_) => List.filled(n, false));
    final List<List<bool>> isFunction = List.generate(n, (_) => List.filled(n, false));

    void setFunctionModule(int r, int c, bool dark) {
      if (r >= 0 && r < n && c >= 0 && c < n) {
        modules[r][c] = dark;
        isFunction[r][c] = true;
      }
    }

    void drawFinderPattern(int topR, int leftC) {
      for (int dr = -1; dr <= 7; dr++) {
        for (int dc = -1; dc <= 7; dc++) {
          final r = topR + dr;
          final c = leftC + dc;
          if (r < 0 || r >= n || c < 0 || c >= n) continue;
          final bool inOuter = (dr >= 0 && dr <= 6 && (dc == 0 || dc == 6)) ||
              (dc >= 0 && dc <= 6 && (dr == 0 || dr == 6));
          final bool inInner = dr >= 2 && dr <= 4 && dc >= 2 && dc <= 4;
          setFunctionModule(r, c, inOuter || inInner);
        }
      }
    }

    drawFinderPattern(0, 0);
    drawFinderPattern(0, n - 7);
    drawFinderPattern(n - 7, 0);

    // Alignment patterns
    final centers = spec.alignmentCenters;
    for (int i = 0; i < centers.length; i++) {
      for (int j = 0; j < centers.length; j++) {
        if ((i == 0 && j == 0) ||
            (i == 0 && j == centers.length - 1) ||
            (i == centers.length - 1 && j == 0)) {
          continue;
        }
        final cr = centers[i];
        final cc = centers[j];
        for (int dr = -2; dr <= 2; dr++) {
          for (int dc = -2; dc <= 2; dc++) {
            final dist = dr.abs() > dc.abs() ? dr.abs() : dc.abs();
            setFunctionModule(cr + dr, cc + dc, dist != 1);
          }
        }
      }
    }

    // Timing patterns
    for (int i = 8; i < n - 8; i++) {
      if (!isFunction[6][i]) setFunctionModule(6, i, i % 2 == 0);
      if (!isFunction[i][6]) setFunctionModule(i, 6, i % 2 == 0);
    }

    // Dark module
    setFunctionModule(4 * spec.version + 9, 8, true);

    // Reserve format information areas
    for (int i = 0; i <= 8; i++) {
      if (i != 6) {
        if (!isFunction[8][i]) setFunctionModule(8, i, false);
        if (!isFunction[i][8]) setFunctionModule(i, 8, false);
      }
      if (i < 8) {
        if (!isFunction[8][n - 1 - i]) setFunctionModule(8, n - 1 - i, false);
        if (!isFunction[n - 1 - i][8]) setFunctionModule(n - 1 - i, 8, false);
      }
    }

    // Version info areas (for V >= 7)
    if (spec.versionInfoBits != null) {
      final vBits = spec.versionInfoBits!;
      for (int i = 0; i < 18; i++) {
        final bit = ((vBits >> i) & 1) == 1;
        final a = n - 11 + (i % 3);
        final b = i ~/ 3;
        setFunctionModule(a, b, bit);
        setFunctionModule(b, a, bit);
      }
    }

    // 4. Place data bits in upward/downward 2-column zig-zag
    final List<int> allBits = [];
    for (final cw in interleaved) {
      for (int b = 7; b >= 0; b--) {
        allBits.add((cw >> b) & 1);
      }
    }

    int bitIdx = 0;
    bool upward = true;
    for (int rightCol = n - 1; rightCol >= 1; rightCol -= 2) {
      if (rightCol == 6) rightCol = 5; // Skip vertical timing pattern column
      for (int step = 0; step < n; step++) {
        final r = upward ? (n - 1 - step) : step;
        for (int dc = 0; dc < 2; dc++) {
          final c = rightCol - dc;
          if (!isFunction[r][c]) {
            bool dark = bitIdx < allBits.length ? (allBits[bitIdx] == 1) : false;
            bitIdx++;
            // Apply Mask 0: (r + c) % 2 == 0
            if ((r + c) % 2 == 0) {
              dark = !dark;
            }
            modules[r][c] = dark;
          }
        }
      }
      upward = !upward;
    }

    // 5. Write Format Information bits for ECC Level L (01), Mask 0 (000) -> 0x77C4
    const int formatBits = 0x77C4;
    bool fBit(int i) => ((formatBits >> i) & 1) == 1;

    // Top-left format info
    for (int i = 0; i <= 5; i++) {
      modules[8][i] = fBit(i);
    }
    modules[8][7] = fBit(6);
    modules[8][8] = fBit(7);
    modules[7][8] = fBit(8);
    for (int i = 9; i < 15; i++) {
      modules[14 - i][8] = fBit(i);
    }

    // Top-right & bottom-left format info
    for (int i = 0; i < 8; i++) {
      modules[8][n - 1 - i] = fBit(i);
    }
    for (int i = 8; i < 15; i++) {
      modules[n - 15 + i][8] = fBit(i);
    }

    return modules;
  }

  static List<int> _computeReedSolomon(List<int> data, int degree) {
    // GF(256) with primitive polynomial 0x11D
    final List<int> exp = List.filled(512, 0);
    final List<int> log = List.filled(256, 0);
    int x = 1;
    for (int i = 0; i < 255; i++) {
      exp[i] = x;
      log[x] = i;
      x <<= 1;
      if ((x & 0x100) != 0) x ^= 0x11D;
    }
    for (int i = 255; i < 512; i++) {
      exp[i] = exp[i - 255];
    }

    int gfMul(int a, int b) {
      if (a == 0 || b == 0) return 0;
      return exp[log[a] + log[b]];
    }

    // Build generator polynomial
    List<int> gen = [1];
    for (int i = 0; i < degree; i++) {
      final List<int> next = List.filled(gen.length + 1, 0);
      final root = exp[i];
      for (int j = 0; j < gen.length; j++) {
        next[j] ^= gen[j];
        next[j + 1] ^= gfMul(gen[j], root);
      }
      gen = next;
    }

    final List<int> rem = List.filled(degree, 0);
    for (final b in data) {
      final factor = b ^ rem[0];
      for (int i = 0; i < degree - 1; i++) {
        rem[i] = rem[i + 1] ^ gfMul(gen[i + 1], factor);
      }
      rem[degree - 1] = gfMul(gen[degree], factor);
    }
    return rem;
  }
}

