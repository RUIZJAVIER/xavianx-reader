import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:anx_reader/l10n/generated/L10n.dart';
import 'package:anx_reader/service/ai/ai_vision_support.dart';
import 'package:flutter/material.dart';

/// Opens a full-screen editor that lets the user crop a fragment out of a
/// screenshot before sending it to the AI.
///
/// Returns the cropped PNG bytes, or the original bytes when the user chooses
/// "whole page". Returns null when the user cancels.
Future<Uint8List?> openScreenshotCrop(
  BuildContext context,
  Uint8List imageBytes,
) {
  return Navigator.of(context).push<Uint8List>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _ScreenshotCropPage(imageBytes: imageBytes),
    ),
  );
}

class _ScreenshotCropPage extends StatefulWidget {
  const _ScreenshotCropPage({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_ScreenshotCropPage> createState() => _ScreenshotCropPageState();
}

class _ScreenshotCropPageState extends State<_ScreenshotCropPage> {
  ui.Image? _image;
  bool _loading = true;
  bool _failed = false;

  /// Selection in the coordinates of the image container.
  Rect? _selection;
  Offset? _dragStart;
  Rect? _lastImageRect;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _decode() async {
    try {
      final codec = await ui.instantiateImageCodec(widget.imageBytes);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _image = frame.image;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Rect _clampTo(Rect rect, Rect bounds) {
    final left = rect.left.clamp(bounds.left, bounds.right);
    final top = rect.top.clamp(bounds.top, bounds.bottom);
    final right = rect.right.clamp(bounds.left, bounds.right);
    final bottom = rect.bottom.clamp(bounds.top, bounds.bottom);
    return Rect.fromLTRB(
      left < right ? left : right,
      top < bottom ? top : bottom,
      left < right ? right : left,
      top < bottom ? bottom : top,
    );
  }

  Future<void> _finish({required bool wholePage}) async {
    if (_busy) return;
    final image = _image;
    final imageRect = _lastImageRect;
    if (wholePage || image == null || imageRect == null || _selection == null) {
      Navigator.of(context).pop(widget.imageBytes);
      return;
    }

    final selection = _clampTo(_selection!, imageRect);
    if (selection.width < 12 || selection.height < 12) {
      Navigator.of(context).pop(widget.imageBytes);
      return;
    }

    setState(() => _busy = true);
    try {
      final scaleX = image.width / imageRect.width;
      final scaleY = image.height / imageRect.height;
      final src = Rect.fromLTWH(
        (selection.left - imageRect.left) * scaleX,
        (selection.top - imageRect.top) * scaleY,
        selection.width * scaleX,
        selection.height * scaleY,
      ).intersect(
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      );

      final bytes = await _crop(image, src);
      if (!mounted) return;
      Navigator.of(context).pop(
        bytes == null
            ? widget.imageBytes
            : AiVisionSupport.prepareImageForVision(bytes),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(widget.imageBytes);
    }
  }

  Future<Uint8List?> _crop(ui.Image image, Rect src) async {
    final width = src.width.round().clamp(1, image.width);
    final height = src.height.round().clamp(1, image.height);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      image,
      src,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..filterQuality = FilterQuality.high,
    );
    final picture = recorder.endRecording();
    final cropped = await picture.toImage(width, height);
    final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
    cropped.dispose();
    picture.dispose();
    return data?.buffer.asUint8List();
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed || _image == null) {
      return Center(
        child: Text(L10n.of(context).aiCaptureUnavailable),
      );
    }

    final image = _image!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
        final fitted = applyBoxFit(
          BoxFit.contain,
          Size(image.width.toDouble(), image.height.toDouble()),
          containerSize,
        );
        final dstSize = fitted.destination;
        final imageRect = Rect.fromLTWH(
          (containerSize.width - dstSize.width) / 2,
          (containerSize.height - dstSize.height) / 2,
          dstSize.width,
          dstSize.height,
        );
        // Remembered for the crop math on "Analyze".
        _lastImageRect = imageRect;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            final p = _clampPoint(details.localPosition, imageRect);
            setState(() {
              _dragStart = p;
              _selection = Rect.fromPoints(p, p);
            });
          },
          onPanUpdate: (details) {
            final start = _dragStart;
            if (start == null) return;
            final p = _clampPoint(details.localPosition, imageRect);
            setState(() {
              _selection = Rect.fromPoints(start, p);
            });
          },
          onPanEnd: (_) {
            final selection = _selection;
            if (selection == null) return;
            if (selection.width < 12 || selection.height < 12) {
              setState(() => _selection = null);
            }
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(color: Theme.of(context).colorScheme.surface),
              ),
              Positioned(
                left: imageRect.left,
                top: imageRect.top,
                width: imageRect.width,
                height: imageRect.height,
                child: Image.memory(
                  widget.imageBytes,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                  gaplessPlayback: true,
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SelectionPainter(
                      selection: _selection == null
                          ? null
                          : _clampTo(_selection!, imageRect),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Offset _clampPoint(Offset point, Rect bounds) {
    return Offset(
      point.dx.clamp(bounds.left, bounds.right),
      point.dy.clamp(bounds.top, bounds.bottom),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).aiVisionCropTitle),
        actions: [
          TextButton(
            onPressed:
                _image == null ? null : () => setState(() => _selection = null),
            child: Text(L10n.of(context).aiVisionCropReset),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              L10n.of(context).aiVisionCropHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(child: _buildBody(context)),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _busy ? null : () => _finish(wholePage: true),
                      child: Text(L10n.of(context).aiVisionCropUseFull),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : () => _finish(wholePage: false),
                      child: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(L10n.of(context).aiVisionCropSend),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectionPainter extends CustomPainter {
  const _SelectionPainter({required this.selection});

  final Rect? selection;

  @override
  void paint(Canvas canvas, Size size) {
    final sel = selection;
    if (sel == null) {
      return;
    }

    final dim = Paint()..color = Colors.black.withValues(alpha: 0.55);
    canvas.drawRect(Rect.fromLTRB(0, 0, size.width, sel.top), dim);
    canvas.drawRect(Rect.fromLTRB(0, sel.bottom, size.width, size.height), dim);
    canvas.drawRect(Rect.fromLTRB(0, sel.top, sel.left, sel.bottom), dim);
    canvas.drawRect(Rect.fromLTRB(sel.right, sel.top, size.width, sel.bottom), dim);

    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;
    canvas.drawRect(sel, border);
  }

  @override
  bool shouldRepaint(_SelectionPainter oldDelegate) =>
      oldDelegate.selection != selection;
}
