import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../ui/completion_share_card.dart';

/// Renders and shares exact 1080 x 1920 completion cards.
class ShareCardService {
  const ShareCardService();

  /// Renders [data] away from the visible widget tree.
  ///
  /// The independent render pipeline makes the output resolution identical on
  /// phones and tablets. Room art is decoded before capture so it cannot be
  /// missing from the resulting PNG.
  Future<Uint8List> renderPng({
    required BuildContext context,
    required CompletionShareCardData data,
  }) async {
    final view = View.of(context);
    final textDirection = Directionality.maybeOf(context) ?? TextDirection.ltr;
    final mediaQuery = MediaQueryData(
      size: CompletionShareCard.canvasSize,
      devicePixelRatio: 1,
      textScaler: TextScaler.noScaling,
      platformBrightness: Brightness.dark,
      padding: EdgeInsets.zero,
      viewPadding: EdgeInsets.zero,
      viewInsets: EdgeInsets.zero,
    );
    final card = InheritedTheme.captureAll(
      context,
      MediaQuery(
        data: mediaQuery,
        child: Directionality(
          textDirection: textDirection,
          child: CompletionShareCard(data: data),
        ),
      ),
    );

    await precacheImage(
      data.roomArt,
      context,
      size: CompletionShareCard.canvasSize,
    );

    return _renderWidget(
      view: view,
      widget: card,
      size: CompletionShareCard.canvasSize,
    );
  }

  /// Writes a new temporary PNG and returns its file.
  Future<File> writeTemporaryPng(
    Uint8List pngBytes, {
    String fileStem = 'prompt-heist-room-cleared',
  }) async {
    final safeStem = fileStem
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File(
      '${Directory.systemTemp.path}/${safeStem.isEmpty ? 'prompt-heist' : safeStem}-$timestamp.png',
    );
    return file.writeAsBytes(pngBytes, flush: true);
  }

  /// Renders the card and opens the platform share sheet.
  ///
  /// Pass the share button's global [sharePositionOrigin]. This is required by
  /// iPadOS to anchor the share popover and is harmless on other platforms.
  Future<ShareResult> shareCompletion({
    required BuildContext context,
    required CompletionShareCardData data,
    required Rect sharePositionOrigin,
  }) async {
    final pngBytes = await renderPng(context: context, data: data);
    final file = await writeTemporaryPng(
      pngBytes,
      fileStem: 'prompt-heist-room-${data.roomNumber}-cleared',
    );

    return SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        title: 'Prompt Heist — ${data.roomTitle}',
        subject: 'I cleared a room in Prompt Heist',
        text:
            'Room ${data.roomNumber} cleared in ${data.effectiveStrokes} strokes.',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  /// Convenience helper for finding an iPad-safe popover anchor from the
  /// share button's [BuildContext].
  static Rect shareOriginFor(BuildContext buttonContext) {
    final renderObject = buttonContext.findRenderObject();
    if (renderObject is RenderBox && renderObject.hasSize) {
      return renderObject.localToGlobal(Offset.zero) & renderObject.size;
    }

    final view = View.maybeOf(buttonContext);
    if (view != null) {
      final logicalSize = view.physicalSize / view.devicePixelRatio;
      return Rect.fromCenter(
        center: logicalSize.center(Offset.zero),
        width: 1,
        height: 1,
      );
    }
    return const Rect.fromLTWH(0, 0, 1, 1);
  }

  Future<Uint8List> _renderWidget({
    required ui.FlutterView view,
    required Widget widget,
    required Size size,
  }) async {
    final repaintBoundary = RenderRepaintBoundary();
    final renderView = RenderView(
      view: view,
      configuration: ViewConfiguration(
        logicalConstraints: BoxConstraints.tight(size),
        physicalConstraints: BoxConstraints.tight(size),
        devicePixelRatio: 1,
      ),
      child: RenderPositionedBox(
        alignment: Alignment.center,
        child: repaintBoundary,
      ),
    );
    final pipelineOwner = PipelineOwner()..rootNode = renderView;
    final focusManager = FocusManager();
    final buildOwner = BuildOwner(focusManager: focusManager);
    RenderObjectToWidgetElement<RenderBox>? rootElement;

    try {
      renderView.prepareInitialFrame();
      rootElement = RenderObjectToWidgetAdapter<RenderBox>(
        container: repaintBoundary,
        child: widget,
      ).attachToRenderTree(buildOwner);
      buildOwner.buildScope(rootElement);
      buildOwner.finalizeTree();

      pipelineOwner.flushLayout();
      pipelineOwner.flushCompositingBits();
      pipelineOwner.flushPaint();

      final image = await repaintBoundary.toImage(pixelRatio: 1);
      try {
        if (image.width != size.width.round() ||
            image.height != size.height.round()) {
          throw StateError(
            'Share card rendered at ${image.width}x${image.height}; '
            'expected ${size.width.round()}x${size.height.round()}.',
          );
        }
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) {
          throw StateError('Flutter could not encode the share card as PNG.');
        }
        return byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        );
      } finally {
        image.dispose();
      }
    } finally {
      if (rootElement != null) {
        RenderObjectToWidgetAdapter<RenderBox>(
          container: repaintBoundary,
        ).attachToRenderTree(buildOwner, rootElement);
        buildOwner.buildScope(rootElement);
        buildOwner.finalizeTree();
      }
      pipelineOwner.rootNode = null;
      focusManager.dispose();
    }
  }
}
