import 'package:free_anime/app/view/app.dart';
import 'package:free_anime/bootstrap.dart';
import 'package:free_anime/core/config/env_config.dart';

void main() {
  bootstrap(() => const App(), flavor: EnvFlavor.staging);
}
