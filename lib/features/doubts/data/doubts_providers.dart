import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/doubt.dart';
import 'models/doubt_answer.dart';
import 'repositories/doubts_repository.dart';

final doubtsRepositoryProvider = Provider<DoubtsRepository>((ref) {
  return DoubtsRepository();
});

final doubtsProvider = FutureProvider.autoDispose<List<Doubt>>((ref) async {
  final repo = ref.watch(doubtsRepositoryProvider);
  return repo.fetchMyDoubts();
});

final doubtAnswersProvider = FutureProvider.autoDispose.family<List<DoubtAnswer>, String>((ref, doubtId) async {
  final repo = ref.watch(doubtsRepositoryProvider);
  return repo.fetchAnswersForDoubt(doubtId);
});
