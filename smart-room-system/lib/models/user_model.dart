/// User Data Model Representing Application User
class UserModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final String sessionId;
  final String profilePath;

  UserModel({required this.id, required this.name, required this.phone, required this.email, required this.sessionId, required this.profilePath});

  /// Convert User Model To Firestore Map
  Map<String, dynamic> toFirestoreMap() {
    return {'id': id, 'Name': name, 'Phone': phone, 'Email': email, 'SessionId': sessionId, 'Path': profilePath, 'createdAt': DateTime.now()};
  }
}
