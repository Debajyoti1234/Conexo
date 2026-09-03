enum ConnectionStatus { pending, accepted, rejected, cancelled, removed }

enum ConnectionDirection { sent, received }

class Connection {
  const Connection({
    required this.id,
    required this.requesterId,
    required this.recipientId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Connection.fromJson(Map<String, dynamic> json) {
    return Connection(
      id: json['id'] as String,
      requesterId: json['requester_id'] as String,
      recipientId: json['recipient_id'] as String,
      status: ConnectionStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => ConnectionStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  final String id;
  final String requesterId;
  final String recipientId;
  final ConnectionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPending => status == ConnectionStatus.pending;
  bool get isAccepted => status == ConnectionStatus.accepted;
  bool get isRejected => status == ConnectionStatus.rejected;
  bool get isCancelled => status == ConnectionStatus.cancelled;
  bool get isRemoved => status == ConnectionStatus.removed;

  ConnectionDirection directionFor(String userId) {
    if (userId == requesterId) return ConnectionDirection.sent;
    if (userId == recipientId) return ConnectionDirection.received;
    throw ArgumentError('User $userId is not involved in this connection');
  }

  String otherUserId(String userId) {
    if (userId == requesterId) return recipientId;
    if (userId == recipientId) return requesterId;
    throw ArgumentError('User $userId is not involved in this connection');
  }
}

class ConnectionResult<T> {
  const ConnectionResult._(this._value, this._error);

  const ConnectionResult.success(T value)
      : this._(value, null);

  const ConnectionResult.failure(String error)
      : this._(null, error);

  final T? _value;
  final String? _error;

  T? get value => _value;
  String? get error => _error;

  bool get isSuccess => error == null;
  bool get isFailure => error != null;
}
