enum RequestStatus {
  resolved, // Решено
  completed, // Завершено
  secondLine, // 2 лин
  noAnswer, // Нет ответа
  autoAnswer, // Автоответчик
  callback, // Перезвон
  busy, // Занято
  languageNeeded; // Нужен оператор

  @override
  String toString() {
    switch (this) {
      case resolved:
        return 'Решено';
      case completed:
        return 'Завершено';
      case secondLine:
        return 'Переведен на 2 линию';
      case noAnswer:
        return 'Нет ответа';
      case autoAnswer:
        return 'Автоответчик';
      case callback:
        return 'Перезвон';
      case busy:
        return 'Занято';
      case languageNeeded:
        return 'Нужен оператор';
    }
  }
}

class Request {
  final String id;
  RequestStatus status;
  String? language;
  String? comment;
  final DateTime createdAt;

  Request({
    required this.id,
    required this.status,
    this.language,
    this.comment,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // 👉 В БД
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'status': status.name,
      'language': language,
      'comment': comment,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  // 👉 Из БД
  factory Request.fromMap(Map<String, dynamic> map) {
    return Request(
      id: map['id'],
      status: RequestStatus.values.firstWhere((e) => e.name == map['status']),
      language: map['language'],
      comment: map['comment'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
    );
  }

  String label() {
    if (status == RequestStatus.languageNeeded &&
        (language?.isNotEmpty ?? false)) {
      return 'Нужен $language оп';
    }
    switch (status) {
      case RequestStatus.resolved:
        return 'Решено';
      case RequestStatus.completed:
        return 'Завершено';
      case RequestStatus.secondLine:
        return '2 лин';
      case RequestStatus.noAnswer:
        return 'Нет ответа';
      case RequestStatus.autoAnswer:
        return 'Автоответчик';
      case RequestStatus.callback:
        return 'Перезвон';
      case RequestStatus.busy:
        return 'Занято';
      case RequestStatus.languageNeeded:
        return 'Нужен оператор';
    }
  }
}
