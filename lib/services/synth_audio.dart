/// Conditional export — picks the Web Audio synthesiser on web,
/// falls back to a no-op stub on every other platform.
export 'synth_audio_stub.dart' if (dart.library.html) 'synth_audio_web.dart';
