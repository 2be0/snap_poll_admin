/// 설문 문항 유형
class QuestionType {
  static const String radio = 'radio';
  static const String checkbox = 'checkbox';
  static const String text = 'text';

  static const List<String> all = [radio, checkbox, text];

  static String label(String type) {
    switch (type) {
      case radio:
        return '단일 선택 (Radio)';
      case checkbox:
        return '복수 선택 (Checkbox)';
      case text:
        return '주관식 (Text)';
      default:
        return type;
    }
  }
}

/// 설문 문항 모델
class Question {
  final String id;
  String text;
  String type; // QuestionType 참고
  List<String> options; // radio/checkbox 전용, text는 빈 리스트
  bool required;

  Question({
    required this.id,
    required this.text,
    required this.type,
    List<String>? options,
    this.required = false,
  }) : options = options ?? [];

  bool get hasOptions =>
      type == QuestionType.radio || type == QuestionType.checkbox;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'type': type,
        'options': options,
        'required': required,
      };

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as String,
      text: json['text'] as String,
      type: json['type'] as String,
      options: (json['options'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      required: json['required'] as bool? ?? false,
    );
  }
}
