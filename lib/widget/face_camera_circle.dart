import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class FaceCameraCircle extends StatelessWidget {
  final CameraController controller;
  final double progress;
  final bool isFaceAligned;
  final double size;

  const FaceCameraCircle({
    super.key,
    required this.controller,
    required this.progress,
    required this.isFaceAligned,
    this.size = 300,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.value.isInitialized) {
      return SizedBox(
        height: size,
        width: size,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return SizedBox(
      height: size,
      width: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 🎥 PERFECT CIRCLE CAMERA
          ClipOval(
            child: SizedBox(
              width: size,
              height: size,
              child: OverflowBox(
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.previewSize!.height,
                    height: controller.value.previewSize!.width,
                    child: CameraPreview(controller),
                  ),
                ),
              ),
            ),
          ),

          // 🔄 PROGRESS RING
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 6,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Colors.greenAccent,
              ),
            ),
          ),

          // 🟢 BORDER
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isFaceAligned ? Colors.greenAccent : Colors.white24,
                width: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
