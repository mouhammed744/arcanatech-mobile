class University {
  final int id;
  final String name;
  final String code;
  final String city;
  final String primaryColor;
  final String secondaryColor;
  final String? accentPreset;
  final int? studentIdDigits;
  final String? studentIdPrefix;
  final String? logoUrl;

  const University({
    required this.id,
    required this.name,
    required this.code,
    required this.city,
    required this.primaryColor,
    required this.secondaryColor,
    this.accentPreset,
    this.studentIdDigits,
    this.studentIdPrefix,
    this.logoUrl,
  });

  factory University.fromJson(Map<String, dynamic> json) => University(
        id: json['id'] as int,
        name: json['name'] as String,
        code: json['code'] as String,
        city: json['city'] as String? ?? '',
        primaryColor: json['primaryColor'] as String? ?? '#6366F1',
        secondaryColor: json['secondaryColor'] as String? ?? '#818CF8',
        accentPreset: json['accentPreset'] as String?,
        studentIdDigits: json['studentIdDigits'] as int?,
        studentIdPrefix: json['studentIdPrefix'] as String?,
        logoUrl: json['logoUrl'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'code': code,
        'city': city,
        'primaryColor': primaryColor,
        'secondaryColor': secondaryColor,
        'accentPreset': accentPreset,
        'studentIdDigits': studentIdDigits,
        'studentIdPrefix': studentIdPrefix,
        'logoUrl': logoUrl,
      };
}

class User {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String role;
  final String? avatar;
  final String? phone;
  final int? universityId;
  final bool isActive;
  final University? university;
  final int? studentId;
  final String? registrationNumber;
  final String? filiere;
  final String? level;

  const User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.role,
    this.avatar,
    this.phone,
    this.universityId,
    this.isActive = true,
    this.university,
    this.studentId,
    this.registrationNumber,
    this.filiere,
    this.level,
  });

  String get fullName => '$firstName $lastName';

  factory User.fromJson(Map<String, dynamic> json) {
    final studentData = json['student'] as Map<String, dynamic>?;
    return User(
      id: json['id'] as int,
      firstName: json['firstName'] as String? ?? json['first_name'] as String? ?? '',
      lastName: json['lastName'] as String? ?? json['last_name'] as String? ?? '',
      email: json['email'] as String,
      role: json['role'] as String,
      avatar: json['avatar'] as String?,
      phone: json['phone'] as String?,
      universityId: json['universityId'] as int? ?? json['university_id'] as int?,
      isActive: json['isActive'] as bool? ?? true,
      university: json['university'] != null
          ? University.fromJson(json['university'] as Map<String, dynamic>)
          : null,
      studentId: studentData?['studentId'] as int?,
      registrationNumber: studentData?['registrationNumber'] as String?,
      level: studentData?['level'] as String?,
      filiere: studentData?['filiere'] is Map
          ? (studentData!['filiere'] as Map<String, dynamic>)['name'] as String?
          : studentData?['filiere'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'role': role,
        'avatar': avatar,
        'phone': phone,
        'universityId': universityId,
        'isActive': isActive,
        'university': university?.toJson(),
        'student': {
          'studentId': studentId,
          'registrationNumber': registrationNumber,
          'level': level,
          'filiere': filiere,
        },
      };
}

class AuthTokens {
  final String accessToken;
  final String refreshToken;

  const AuthTokens({required this.accessToken, required this.refreshToken});

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: json['accessToken'] as String? ?? json['access_token'] as String,
        refreshToken: json['refreshToken'] as String? ?? json['refresh_token'] as String,
      );
}

class LoginResponse {
  final User user;
  final AuthTokens tokens;

  const LoginResponse({required this.user, required this.tokens});

  factory LoginResponse.fromJson(Map<String, dynamic> json) => LoginResponse(
        user: User.fromJson(json['user'] as Map<String, dynamic>),
        tokens: AuthTokens.fromJson(json['tokens'] as Map<String, dynamic>),
      );
}
