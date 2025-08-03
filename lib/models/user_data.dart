class UserData {
  final String name;
  final String selectedCity;
  final String? email;
  final DateTime lastLogin;
  final bool isLoggedIn;

  UserData({
    required this.name,
    required this.selectedCity,
    this.email,
    required this.lastLogin,
    required this.isLoggedIn,
  });

  UserData copyWith({
    String? name,
    String? selectedCity,
    String? email,
    DateTime? lastLogin,
    bool? isLoggedIn,
  }) {
    return UserData(
      name: name ?? this.name,
      selectedCity: selectedCity ?? this.selectedCity,
      email: email ?? this.email,
      lastLogin: lastLogin ?? this.lastLogin,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'selectedCity': selectedCity,
      'email': email,
      'lastLogin': lastLogin.toIso8601String(),
      'isLoggedIn': isLoggedIn,
    };
  }

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
      name: json['name'] ?? '',
      selectedCity: json['selectedCity'] ?? '',
      email: json['email'],
      lastLogin: DateTime.parse(json['lastLogin']),
      isLoggedIn: json['isLoggedIn'] ?? false,
    );
  }

  factory UserData.empty() {
    return UserData(
      name: '',
      selectedCity: '',
      lastLogin: DateTime.now(),
      isLoggedIn: false,
    );
  }
} 