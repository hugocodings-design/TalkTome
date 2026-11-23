import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:talktome/services/wav_silence.dart';

/// WAV PCM 16 bits mono minimal : en-tête 44 octets + [samples] échantillons.
Uint8List _wav(int rate, int samples) {
  final data = samples * 2;
  final b = ByteData(44 + data);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + data, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little);
  b.setUint16(20, 1, Endian.little); // PCM
  b.setUint16(22, 1, Endian.little); // mono
  b.setUint32(24, rate, Endian.little);
  b.setUint32(28, rate * 2, Endian.little);
  b.setUint16(32, 2, Endian.little);
  b.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  b.setUint32(40, data, Endian.little);
  for (var i = 0; i < samples; i++) {
    b.setInt16(44 + i * 2, 1000, Endian.little);
  }
  return b.buffer.asUint8List();
}

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('wav_silence'));
  tearDown(() async => dir.delete(recursive: true));

  test('appends silence and keeps the header consistent', () async {
    final f = File('${dir.path}/a.wav')..writeAsBytesSync(_wav(24000, 2400));
    final added = await appendWavSilence(f.path, 350);
    expect(added, closeTo(0.35, 1e-9));

    final out = f.readAsBytesSync();
    final v = ByteData.sublistView(out);
    expect(out.length, 44 + 2400 * 2 + 8400 * 2);
    expect(v.getUint32(4, Endian.little), out.length - 8);
    expect(v.getUint32(40, Endian.little), (2400 + 8400) * 2);
    expect(v.getInt16(44, Endian.little), 1000); // original audio intact
    expect(v.getInt16(out.length - 2, Endian.little), 0); // silence at the end
  });

  test('leaves files it does not understand untouched', () async {
    final f = File('${dir.path}/b.wav')..writeAsBytesSync([1, 2, 3, 4, 5]);
    expect(await appendWavSilence(f.path, 350), 0);
    expect(f.readAsBytesSync(), [1, 2, 3, 4, 5]);
  });
}
