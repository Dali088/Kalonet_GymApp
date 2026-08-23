import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_controller.dart';

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
