import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../data/repositories/settings_repository.dart';
import '../utils/monster_look.dart';
import '../utils/reward_calculator.dart';
import '../utils/time_format.dart';
import 'collection/collection_screen.dart';
import 'collection/collection_view_model.dart';
import 'collection/draw_screen.dart';
import 'collection/draw_view_model.dart';
import 'collection/share_card.dart';
import 'collection/share_card_screen.dart';
import 'history/history_day_screen.dart';
import 'history/history_day_view_model.dart';
import 'history/history_screen.dart';
import 'history/history_view_model.dart';
import 'home/home_screen.dart';
import 'home/home_view_model.dart';
import 'medication/drug_info_screen.dart';
import 'medication/drug_info_view_model.dart';
import 'medication/medication_edit_screen.dart';
import 'medication/medication_edit_view_model.dart';
import 'medication/medication_list_screen.dart';
import 'medication/medication_list_view_model.dart';
import 'medication/prescription_edit_screen.dart';
import 'medication/prescription_edit_view_model.dart';
import 'monster/monster_screen.dart';
import 'monster/monster_view_model.dart';
import 'result/result_screen.dart';
import 'result/result_view_model.dart';
import 'metrics/metrics_screen.dart';
import 'metrics/metrics_view_model.dart';
import 'welcome/about_screen.dart';
import 'welcome/welcome_screen.dart';
import 'reward/reward_screen.dart';
import 'shell/app_shell.dart';
import 'shell/capture_view_model.dart';

/// [settings]를 듣다가 나이를 확인하지 않았으면 어느 화면이든 나이 확인으로 보낸다.
///
/// 홈·기록·컬렉션·약 관리는 아래 바가 있는 틀([AppShell]) 안의 탭이다.
/// 그 밖의 화면과 탭 안의 상세 화면은 틀 위를 덮는다.
GoRouter buildRouter(SettingsRepository settings) {
  final root = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: root,
    refreshListenable: settings,
    redirect: (context, state) {
      final atWelcome = state.matchedLocation == '/welcome';
      if (!settings.ageConfirmed) return atWelcome ? null : '/welcome';
      return atWelcome ? '/' : null;
    },
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
      GoRoute(
        path: '/metrics',
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => MetricsViewModel(
            medications: context.read(),
            prescriptions: context.read(),
            intakes: context.read(),
            rewards: context.read(),
            settings: context.read(),
          )..load(),
          child: const MetricsScreen(),
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
            labels: context.read(),
            prescriptions: context.read(),
            rewards: context.read(),
          )..detect(),
          child: const ResultScreen(),
        ),
      ),
      GoRoute(
        path: '/share',
        // 카드에 넣을 것은 컬렉션 화면에서 메모리로만 넘긴다. 그냥 들어오면 컬렉션으로.
        redirect: (context, state) =>
            state.extra is ShareCardData ? null : '/collection',
        builder: (context, state) =>
            ShareCardScreen(data: state.extra! as ShareCardData),
      ),
      GoRoute(
        path: '/draw',
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) =>
              DrawViewModel(collection: context.read(), rewards: context.read())
                ..load(),
          child: const DrawScreen(),
        ),
      ),
      GoRoute(
        path: '/reward',
        // 보상 결과는 저장 직후에만 메모리로 넘긴다. 그냥 들어오면 홈으로.
        redirect: (context, state) =>
            state.extra is (RewardOutcome, Map<int, MonsterLook?>) ? null : '/',
        builder: (context, state) {
          final (outcome, looks) =
              state.extra! as (RewardOutcome, Map<int, MonsterLook?>);
          return RewardScreen(outcome: outcome, looks: looks);
        },
      ),
      GoRoute(
        path: '/monsters/:pid',
        redirect: (context, state) =>
            int.tryParse(state.pathParameters['pid']!) == null ? '/' : null,
        builder: (context, state) => ChangeNotifierProvider(
          create: (context) => MonsterViewModel(
            prescriptionId: int.parse(state.pathParameters['pid']!),
            rewards: context.read(),
            prescriptions: context.read(),
            intakes: context.read(),
          )..load(),
          child: const MonsterScreen(),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => ChangeNotifierProvider(
          create: (context) => CaptureViewModel(picker: context.read()),
          child: AppShell(location: state.uri.path, child: child),
        ),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) => NoTransitionPage(
              child: ChangeNotifierProvider(
                create: (context) => HomeViewModel(
                  intakes: context.read(),
                  medications: context.read(),
                  prescriptions: context.read(),
                  rewards: context.read(),
                  collection: context.read(),
                  backup: context.read(),
                  backupFiles: context.read(),
                )..load(),
                child: const HomeScreen(),
              ),
            ),
          ),
          GoRoute(
            path: '/history',
            pageBuilder: (context, state) => NoTransitionPage(
              child: ChangeNotifierProvider(
                create: (context) => HistoryViewModel(
                  intakes: context.read(),
                  medications: context.read(),
                )..load(),
                child: const HistoryScreen(),
              ),
            ),
            routes: [
              GoRoute(
                parentNavigatorKey: root,
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
          GoRoute(
            path: '/collection',
            pageBuilder: (context, state) => NoTransitionPage(
              child: ChangeNotifierProvider(
                create: (context) => CollectionViewModel(
                  collection: context.read(),
                  rewards: context.read(),
                )..load(),
                child: const CollectionScreen(),
              ),
            ),
          ),
          GoRoute(
            path: '/medications',
            pageBuilder: (context, state) => NoTransitionPage(
              child: ChangeNotifierProvider(
                create: (context) => MedicationListViewModel(
                  medications: context.read(),
                  prescriptions: context.read(),
                  rewards: context.read(),
                )..load(),
                child: const MedicationListScreen(),
              ),
            ),
            routes: [
              GoRoute(
                parentNavigatorKey: root,
                path: 'prescriptions/new',
                builder: (context, state) => _prescriptionEdit(null),
              ),
              GoRoute(
                parentNavigatorKey: root,
                path: 'prescriptions/:pid',
                redirect: (context, state) =>
                    int.tryParse(state.pathParameters['pid']!) == null
                    ? '/medications'
                    : null,
                builder: (context, state) =>
                    _prescriptionEdit(int.parse(state.pathParameters['pid']!)),
              ),
              GoRoute(
                parentNavigatorKey: root,
                path: 'new',
                builder: (context, state) => ChangeNotifierProvider(
                  create: (context) => MedicationEditViewModel(
                    medications: context.read(),
                    labels: context.read(),
                    drugs: context.read(),
                  )..load(),
                  child: const MedicationEditScreen(),
                ),
              ),
              GoRoute(
                parentNavigatorKey: root,
                path: ':id',
                redirect: (context, state) =>
                    int.tryParse(state.pathParameters['id']!) == null
                    ? '/medications'
                    : null,
                builder: (context, state) => ChangeNotifierProvider(
                  create: (context) => MedicationEditViewModel(
                    medications: context.read(),
                    labels: context.read(),
                    drugs: context.read(),
                    medicationId: int.parse(state.pathParameters['id']!),
                  )..load(),
                  child: const MedicationEditScreen(),
                ),
                routes: [
                  GoRoute(
                    parentNavigatorKey: root,
                    path: 'info',
                    builder: (context, state) => ChangeNotifierProvider(
                      create: (context) => DrugInfoViewModel(
                        medicationId: int.parse(state.pathParameters['id']!),
                        medications: context.read(),
                        drugs: context.read(),
                      )..load(),
                      child: const DrugInfoScreen(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

Widget _prescriptionEdit(int? id) => ChangeNotifierProvider(
  create: (context) => PrescriptionEditViewModel(
    prescriptions: context.read(),
    medications: context.read(),
    labels: context.read(),
    drugs: context.read(),
    prescriptionId: id,
  )..load(),
  child: const PrescriptionEditScreen(),
);
