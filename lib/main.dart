import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'data/repositories/intake_repository.dart';
import 'data/repositories/medication_repository.dart';
import 'data/services/camera_service.dart';
import 'data/services/database_service.dart';
import 'data/services/fake_pill_detector.dart';
import 'data/services/model_bundle.dart';
import 'data/services/photo_storage_service.dart';
import 'data/services/pill_detector.dart';
import 'data/services/pill_label_service.dart';
import 'data/services/yolo_pill_detector.dart';
import 'ui/common/theme.dart';
import 'ui/router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 모델을 받지 않았으면(scripts/fetch_model.sh) 고정된 결과를 돌려주는 가짜 탐지기를 쓴다.
  final model = await ModelBundle.find(rootBundle);
  final labels = model == null
      ? PillLabelService()
      : PillLabelService(asset: model.labelsAsset);
  runApp(
    PillboxApp(
      database: DatabaseService(),
      photos: PhotoStorageService(),
      camera: CameraService(),
      detector: model == null
          ? FakePillDetector()
          : YoloPillDetector(modelAsset: model.modelAsset, labels: labels),
      labels: labels,
    ),
  );
}

class PillboxApp extends StatefulWidget {
  const PillboxApp({
    super.key,
    required this.database,
    required this.photos,
    required this.camera,
    required this.detector,
    required this.labels,
  });

  final DatabaseService database;
  final PhotoStorageService photos;
  final CameraService camera;
  final PillDetector detector;
  final PillLabelService labels;

  @override
  State<PillboxApp> createState() => _PillboxAppState();
}

class _PillboxAppState extends State<PillboxApp> {
  final GoRouter _router = buildRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: widget.photos),
        Provider.value(value: widget.camera),
        Provider.value(value: widget.detector),
        Provider.value(value: widget.labels),
        ChangeNotifierProvider(
          create: (_) => MedicationRepository(widget.database, widget.photos),
        ),
        ChangeNotifierProvider(
          create: (_) => IntakeRepository(widget.database, widget.photos),
        ),
      ],
      child: MaterialApp.router(
        title: 'pillbbox',
        theme: appTheme,
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        routerConfig: _router,
      ),
    );
  }
}
