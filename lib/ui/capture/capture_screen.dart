import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'capture_view_model.dart';

class CaptureScreen extends StatelessWidget {
  const CaptureScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CaptureViewModel>();

    void showResult(Uint8List? photo) {
      if (photo != null && context.mounted) {
        context.pushReplacement('/result', extra: photo);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('촬영')),
      body: switch (vm.status) {
        CaptureStatus.opening => const Center(
          child: CircularProgressIndicator(),
        ),
        CaptureStatus.unavailable => _Unavailable(
          onUseSample: () async => showResult(await vm.loadSamplePhoto()),
        ),
        CaptureStatus.ready || CaptureStatus.capturing => Column(
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(vm.cameraController!),
                  const Align(
                    alignment: Alignment.bottomCenter,
                    child: _Guide(),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FloatingActionButton.large(
                onPressed: vm.status == CaptureStatus.ready
                    ? () async => showResult(await vm.takePicture())
                    : null,
                child: const Icon(Icons.camera),
              ),
            ),
          ],
        ),
      },
    );
  }
}

class _Guide extends StatelessWidget {
  const _Guide();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.black54,
      padding: const EdgeInsets.all(12),
      child: const Text(
        '단색 배경 위에 알약끼리 떨어지게 놓고, 바로 위에서 찍어 주세요',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white),
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.onUseSample});

  final VoidCallback onUseSample;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography, size: 48),
            const SizedBox(height: 12),
            const Text('카메라를 쓸 수 없습니다', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onUseSample,
              child: const Text('샘플 사진으로 계속'),
            ),
          ],
        ),
      ),
    );
  }
}
