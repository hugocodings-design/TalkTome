import 'dart:io';
import 'dart:typed_data';

/// Ajoute [ms] millisecondes de silence à la fin du WAV [path] et renvoie la
/// durée ajoutée en secondes. Ne touche à rien (renvoie 0) si le fichier
/// n'est pas un WAV PCM/float dont les données sont le dernier bloc.
Future<double> appendWavSilence(String path, int ms) async {
  if (ms <= 0) return 0;
  final file = File(path);
  final bytes = await file.readAsBytes();
  if (bytes.length < 12 ||
      String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
      String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
    return 0;
  }
  final view = ByteData.sublistView(bytes);
  int? format, channels, rate, bits, dataSizeAt, dataEnd;
  var p = 12;
  while (p + 8 <= bytes.length) {
    final id = String.fromCharCodes(bytes.sublist(p, p + 4));
    final size = view.getUint32(p + 4, Endian.little);
    if (id == 'fmt ' && p + 24 <= bytes.length) {
      format = view.getUint16(p + 8, Endian.little);
      channels = view.getUint16(p + 10, Endian.little);
      rate = view.getUint32(p + 12, Endian.little);
      bits = view.getUint16(p + 22, Endian.little);
    } else if (id == 'data') {
      dataSizeAt = p + 4;
      dataEnd = p + 8 + size;
      break;
    }
    p += 8 + size + (size & 1);
  }
  // 1 = PCM entier, 3 = flottant : dans les deux cas, des zéros = silence.
  if ((format != 1 && format != 3) ||
      channels == null || rate == null || bits == null || rate == 0 ||
      dataSizeAt == null || dataEnd == null || dataEnd != bytes.length) {
    return 0;
  }

  final frames = rate * ms ~/ 1000;
  final extra = frames * channels * (bits ~/ 8);
  final out = Uint8List(bytes.length + extra)..setRange(0, bytes.length, bytes);
  final outView = ByteData.sublistView(out);
  outView.setUint32(dataSizeAt, dataEnd - dataSizeAt - 4 + extra, Endian.little);
  outView.setUint32(4, out.length - 8, Endian.little);
  await file.writeAsBytes(out, flush: false);
  return frames / rate;
}
