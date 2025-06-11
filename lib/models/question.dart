class Question {
  final String categorie;
  final String question;
  final List<Answer> reponses;
  final String explication;
  final String difficulte;
  final String? image;

  Question({
    required this.categorie,
    required this.question,
    required this.reponses,
    required this.explication,
    required this.difficulte,
    this.image,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      categorie: json['categorie'] ?? '',
      question: json['question'] ?? '',
      reponses: (json['reponses'] as List)
          .map((r) => Answer.fromJson(r))
          .toList(),
      explication: json['explication'] ?? '',
      difficulte: json['difficulte'] ?? '',
      image: json['image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'categorie': categorie,
      'question': question,
      'reponses': reponses.map((r) => r.toJson()).toList(),
      'explication': explication,
      'difficulte': difficulte,
      'image': image,
    };
  }
}

class Answer {
  final String texte;
  final bool correct;

  Answer({required this.texte, required this.correct});

  factory Answer.fromJson(Map<String, dynamic> json) {
    return Answer(
      texte: json['texte'] ?? '',
      correct: json['correct'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'texte': texte,
      'correct': correct,
    };
  }
}
