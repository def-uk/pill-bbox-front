import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
import 'reward/reward_screen.dart';

GoRouter buildRouter() => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => ChangeNotifierProvider(
        create: (context) => HomeViewModel(
          intakes: context.read(),
          medications: context.read(),
          prescriptions: context.read(),
          rewards: context.read(),
          collection: context.read(),
          picker: context.read(),
          backup: context.read(),
          backupFiles: context.read(),
        )..load(),
        child: const HomeScreen(),
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
      path: '/collection',
      builder: (context, state) => ChangeNotifierProvider(
        create: (context) => CollectionViewModel(
          collection: context.read(),
          rewards: context.read(),
        )..load(),
        child: const CollectionScreen(),
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
      path: '/medications',
      builder: (context, state) => ChangeNotifierProvider(
        create: (context) => MedicationListViewModel(
          medications: context.read(),
          prescriptions: context.read(),
          rewards: context.read(),
        )..load(),
        child: const MedicationListScreen(),
      ),
      routes: [
        GoRoute(
          path: 'prescriptions/new',
          builder: (context, state) => _prescriptionEdit(null),
        ),
        GoRoute(
          path: 'prescriptions/:pid',
          redirect: (context, state) =>
              int.tryParse(state.pathParameters['pid']!) == null
              ? '/medications'
              : null,
          builder: (context, state) =>
              _prescriptionEdit(int.parse(state.pathParameters['pid']!)),
        ),
        GoRoute(
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
