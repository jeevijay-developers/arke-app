import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/mentor_info.dart';
import 'models/mentor_message.dart';
import 'repositories/mentor_chat_repository.dart';

final mentorChatRepositoryProvider = Provider<MentorChatRepository>(
  (_) => MentorChatRepository(),
);

final assignedMentorProvider = FutureProvider.autoDispose<MentorInfo?>((ref) {
  return ref.watch(mentorChatRepositoryProvider).fetchAssignedMentor();
});

final mentorMessagesStreamProvider =
    StreamProvider.autoDispose.family<List<MentorMessage>, String>((ref, mentorId) {
  return ref.watch(mentorChatRepositoryProvider).messagesStream(mentorId);
});

final mentorReviewsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, mentorId) {
  return ref.watch(mentorChatRepositoryProvider).fetchMentorReviews(mentorId);
});

final myMentorReviewProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>?, String>((ref, mentorId) {
  return ref.watch(mentorChatRepositoryProvider).fetchMyReview(mentorId);
});
