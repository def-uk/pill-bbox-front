import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../data/models/intake_record.dart';
import 'home_view_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('오늘')),
      body: switch (vm) {
        HomeViewModel(loading: true) => const Center(
          child: CircularProgressIndicator(),
        ),
        HomeViewModel(intakes: []) => const Center(
          child: Text('아직 오늘 복용 기록이 없습니다'),
        ),
        _ => ListView(
          children: [
            for (final intake in vm.intakes)
              ListTile(
                leading: Icon(
                  intake.source == IntakeSource.camera
                      ? Icons.photo_camera
                      : Icons.edit,
                ),
                title: Text(intake.name),
                subtitle: Text(_formatTime(intake.takenAt)),
                trailing: Text('${intake.count}정'),
              ),
          ],
        ),
      },
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/capture'),
        icon: const Icon(Icons.photo_camera),
        label: const Text('촬영'),
      ),
    );
  }

  static String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
