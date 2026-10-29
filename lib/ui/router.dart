import 'dart:typed_data';

import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'capture/capture_screen.dart';
import 'capture/capture_view_model.dart';
import 'home/home_screen.dart';
import 'home/home_view_model.dart';
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
  ],
);
