import 'package:flutter/widgets.dart';

/// 연출을 보여 줄지. 시스템 설정에서 애니메이션을 줄였으면 false (docs/MVP.md 8장).
bool motionOf(BuildContext context) =>
    !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);
