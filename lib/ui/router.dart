import 'dart:typed_data';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../utils/time_format.dart';
import 'capture/capture_screen.dart';
import 'capture/capture_view_model.dart';
import 'history/history_day_screen.dart';
import 'history/history_day_view_model.dart';
import 'history/history_screen.dart';
import 'history/history_view_model.dart';
import 'home/home_screen.dart';
import 'home/home_view_model.dart';
import 'medication/medication_edit_screen.dart';
import 'medication/medication_edit_view_model.dart';
import 'medication/medication_list_screen.dart';
import 'medication/medication_list_view_model.dart';
import 'result/result_screen.dart';
import 'result/result_view_model.dart';

GoRouter buildRouter() => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => ChangeNotifierProvider(
        create: (context) =>
            HomeViewModel(intakes: context.read(), medications: context.read())
              ..load(),
        child: const HomeScreen(),
      ),
    ),
    GoRoute(
      path: '/capture',
      builder: (context, state) => ChangeNotifierProvider(
        create: (context) => CaptureViewModel(camera: context.read())..open(),
        child: const CaptureScreen(),
      ),
    ),
    GoRoute(
      path: '/result',
      // 사진은 화면 사이에 메모리로만 넘긴다. 사진 없이 들어오면 홈으로.
      redirect: (context, state) => state.extra is Uint8List ? null : '/',
      builder: (context, state) => ChangeNotifierProvider(
        create: (context) => ResultViewModel(
          photo: state.extra! as Uint8List,
          detector: context.read(),
          medications: context.read(),
          intakes: context.read(),
        )..detect(),
        child: const ResultScreen(),
      ),
    ),
    GoRoute(
      path: '/medications',
      builder: (context, state) => ChangeNotifierProvider(
        create: (context) =>
            MedicationListViewModel(medications: context.read())..load(),
        child: const MedicationListScreen(),
      ),
      routes: [
        GoRoute(
          path: 'new',
          builder: (context, state) => ChangeNotifierProvider(
            create: (context) => MedicationEditViewModel(
              medications: context.read(),
              labels: context.read(),
            )..load(),
            child: const MedicationEditScreen(),
          ),
        ),
        GoRoute(
          path: ':id',
          redirect: (context, state) =>
              int.tryParse(state.pathParameters['id']!) == null
              ? '/medications'
              : null,
          builder: (context, state) => ChangeNotifierProvider(
            create: (context) => MedicationEditViewModel(
              medications: context.read(),
              labels: context.read(),
              medicationId: int.parse(state.pathParameters['id']!),
            )..load(),
            child: const MedicationEditScreen(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => ChangeNotifierProvider(
        create: (context) => HistoryViewModel(
          intakes: context.read(),
          medications: context.read(),
        )..load(),
        child: const HistoryScreen(),
      ),
      routes: [
        GoRoute(
          path: ':date',
          redirect: (context, state) =>
              parseDateKey(state.pathParameters['date']!) == null
              ? '/history'
              : null,
          builder: (context, state) => ChangeNotifierProvider(
            create: (context) => HistoryDayViewModel(
              day: parseDateKey(state.pathParameters['date']!)!,
              intakes: context.read(),
              medications: context.read(),
              photos: context.read(),
            )..load(),
            child: const HistoryDayScreen(),
          ),
        ),
      ],
    ),
  ],
);
