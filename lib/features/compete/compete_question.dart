class CompeteQuestion {
  final String id;
  final String subject;
  final String topic;
  final String difficulty;
  final String questionText;
  final List<String> options;
  final int correct;
  final String? explanation;

  const CompeteQuestion({
    required this.id,
    required this.subject,
    required this.topic,
    required this.difficulty,
    required this.questionText,
    required this.options,
    required this.correct,
    this.explanation,
  });

  factory CompeteQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'];
    final List<String> opts;
    if (rawOptions is List) {
      opts = rawOptions.map((e) => e.toString()).toList();
    } else {
      opts = [];
    }
    return CompeteQuestion(
      id:          json['id'] as String,
      subject:     json['subject'] as String? ?? '',
      topic:       json['topic'] as String? ?? '',
      difficulty:  json['difficulty'] as String? ?? '',
      questionText: json['question_text'] as String? ?? '',
      options:     opts,
      correct:     (json['correct_index'] as num?)?.toInt() ?? 0,
      explanation: json['explanation'] as String?,
    );
  }
}
