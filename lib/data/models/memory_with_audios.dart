import 'audiography.dart';
import 'memory.dart';

/// Un recuerdo junto con todas sus audiografías, listo para el feed.
class MemoryWithAudios {
  final Memory memory;
  final List<Audiography> audios;
  const MemoryWithAudios(this.memory, this.audios);
}
