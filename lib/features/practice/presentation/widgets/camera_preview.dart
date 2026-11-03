import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

import '../../../../app/theme/app_colors.dart';

/// Interactive live camera & microphone setup preview
class CameraPreviewWidget extends StatefulWidget {
  const CameraPreviewWidget({
    super.key,
    this.isCameraOn = true,
    this.isMicOn = true,
    this.cameraWorking = false,
    this.micWorking = false,
    this.micLevel = 0,
    this.controller,
    this.onToggleCamera,
    this.onToggleMic,
  });

  final bool isCameraOn;
  final bool isMicOn;
  final bool cameraWorking;
  final bool micWorking;
  final double micLevel;
  final CameraController? controller;
  final ValueChanged<bool>? onToggleCamera;
  final ValueChanged<bool>? onToggleMic;

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

/// Crops the camera feed to fill its viewport while preserving the sensor's
/// aspect ratio. This avoids letterboxing in both setup and live previews.
class CoverCameraPreview extends StatelessWidget {
  const CoverCameraPreview({super.key, required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;
    if (!controller.value.isInitialized || previewSize == null) {
      return const SizedBox.shrink();
    }
    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: previewSize.height,
            height: previewSize.width,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.navy, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1814213D),
            offset: Offset(4, 5),
            blurRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            // Live camera feed or the explicit "Camera Off" state
            Positioned.fill(
              child: widget.isCameraOn
                  ? _buildCameraFeed()
                  : _buildCameraOffState(),
            ),

            // Face positioning guideline oval
            if (widget.isCameraOn)
              Center(
                child: Container(
                  width: 140,
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(70),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.45),
                      width: 2,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                ),
              ),

            // Top Status Bar: Camera & Mic Indicators
            Positioned(
              top: 14,
              left: 14,
              right: 14,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: widget.isCameraOn && widget.cameraWorking
                                ? Colors.green
                                : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          !widget.isCameraOn
                              ? 'Video: Off'
                              : widget.cameraWorking
                                  ? 'Video: Live'
                                  : 'Video: Connecting',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.isMicOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                          size: 14,
                          color: widget.isMicOn && widget.micWorking
                              ? AppColors.yellow
                              : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          !widget.isMicOn
                              ? 'Mic: Off'
                              : widget.micWorking
                                  ? 'Mic: Active'
                                  : 'Mic: Unavailable',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Audio Meter and Toggles
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.graphic_eq_rounded,
                      color: AppColors.yellow,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    // Live audio frequency bars
                    Expanded(
                      child: widget.isMicOn && widget.micWorking
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(14, (index) {
                                const levels = [
                                  .42, .7, .55, .9, .64, .82, .48,
                                  .76, .96, .61, .8, .5, .72, .44,
                                ];
                                final barHeight =
                                    3.0 + widget.micLevel * 18 * levels[index];
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 140),
                                  width: 3.5,
                                  height: barHeight,
                                  decoration: BoxDecoration(
                                    color: index > 10
                                        ? AppColors.coral
                                        : (index > 7
                                            ? AppColors.yellow
                                            : Colors.greenAccent),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                );
                              }),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 12),
                    // Camera Toggle
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      icon: Icon(
                        widget.isCameraOn
                            ? Icons.videocam_rounded
                            : Icons.videocam_off_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () =>
                          widget.onToggleCamera?.call(!widget.isCameraOn),
                      tooltip: 'Toggle Camera',
                    ),
                    const SizedBox(width: 4),
                    // Mic Toggle
                    IconButton(
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                      icon: Icon(
                        widget.isMicOn ? Icons.mic_rounded : Icons.mic_off_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () =>
                          widget.onToggleMic?.call(!widget.isMicOn),
                      tooltip: 'Toggle Mic',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraFeed() {
    final controller = widget.controller;
    if (widget.cameraWorking &&
        controller != null &&
        controller.value.isInitialized) {
      return CoverCameraPreview(controller: controller);
    }
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.camera_alt_outlined,
          size: 42,
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _buildCameraOffState() {
    return Container(
      color: const Color(0xFF111827),
      child: const Center(
        child: Icon(Icons.videocam_off_rounded, size: 48, color: Colors.white38),
      ),
    );
  }
}

