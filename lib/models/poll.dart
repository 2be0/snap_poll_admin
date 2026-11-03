import 'question.dart';

/// 설문에 대한 한 건의 응답
class PollResponse {
  final String id;
  final String pollId;
  final Map<String, dynamic> answers; // questionId -> String 또는 List<String>
  final DateTime submittedAt;

  PollResponse({
    required this.id,
    required this.pollId,
    required this.answers,
    required this.submittedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'poll_id': pollId,
        'answers': answers,
        'submitted_at': submittedAt.toIso8601String(),
      };

  factory PollResponse.fromJson(Map<String, dynamic> json) {
    return PollResponse(
      id: json['id'] as String,
      pollId: json['poll_id'] as String,
      answers: Map<String, dynamic>.from(json['answers'] as Map),
      submittedAt: DateTime.parse(json['submitted_at'] as String),
    );
  }
}

/// 설문 모델
class Poll {
  final String id;
  String title;
  String description;
  final DateTime createdAt;
  DateTime? publishedAt;
  bool isPublished;
  List<Question> questions;
  final List<PollResponse> responses;

  Poll({
    required this.id,
    required this.title,
    required this.description,
    required this.createdAt,
    this.publishedAt,
    this.isPublished = false,
    required this.questions,
    List<PollResponse>? responses,
  }) : responses = responses ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'created_at': createdAt.toIso8601String(),
        'published_at': publishedAt?.toIso8601String(),
        'is_published': isPublished,
        'questions': questions.map((q) => q.toJson()).toList(),
        'responses': responses.map((r) => r.toJson()).toList(),
      };

  factory Poll.fromJson(Map<String, dynamic> json) {
    return Poll(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : null,
      isPublished: json['is_published'] as bool? ?? false,
      questions: (json['questions'] as List<dynamic>)
          .map((e) => Question.fromJson(e as Map<String, dynamic>))
          .toList(),
      responses: (json['responses'] as List<dynamic>? ?? [])
          .map((e) => PollResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
