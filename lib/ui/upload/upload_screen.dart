import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'upload_view_model.dart';

class UploadScreen extends StatelessWidget {
  const UploadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<UploadViewModel>();

    void showResult(Uint8List? photo) {
      if (photo != null && context.mounted) {
        context.pushReplacement('/result', extra: photo);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('사진 올리기')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_photo_alternate_outlined, size: 64),
              const SizedBox(height: 16),
              const Text(
                '단색 배경 위에 알약끼리 떨어지게 놓고,\n바로 위에서 찍은 사진을 골라 주세요',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: vm.picking
                    ? null
                    : () async => showResult(await vm.pickPhoto()),
                icon: const Icon(Icons.photo_library),
                label: const Text('사진 고르기'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: vm.picking
                    ? null
                    : () async => showResult(await vm.loadSamplePhoto()),
                child: const Text('샘플 사진으로 해 보기'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
