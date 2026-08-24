import 'dart:io';

import 'package:image/image.dart' as image;

const _canvasSize = 1024;
final _background = image.ColorRgba8(255, 245, 225, 255);
final _transparent = image.ColorRgba8(0, 0, 0, 0);

void main() {
  final sourceFile = File('assets/mascots/student/cooked.png');
  final source = image.decodePng(sourceFile.readAsBytesSync());
  if (source == null) {
    throw StateError('Could not decode ${sourceFile.path}.');
  }

  _writeIcon(
    source: source,
    destination: 'assets/icon/student_cooked_icon.png',
    mascotHeight: 820,
    background: _background,
  );
  _writeIcon(
    source: source,
    destination: 'assets/icon/student_cooked_foreground.png',
    mascotHeight: 680,
    background: _transparent,
  );
}

void _writeIcon({
  required image.Image source,
  required String destination,
  required int mascotHeight,
  required image.Color background,
}) {
  final mascot = image.copyResize(
    source,
    height: mascotHeight,
    interpolation: image.Interpolation.cubic,
  );
  final canvas = image.Image(
    width: _canvasSize,
    height: _canvasSize,
    numChannels: 4,
  );
  image.fill(canvas, color: background);
  image.compositeImage(canvas, mascot, center: true);
  File(destination).writeAsBytesSync(image.encodePng(canvas));
}
