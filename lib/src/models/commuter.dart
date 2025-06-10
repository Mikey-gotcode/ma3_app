class Commuter {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? phone;

  Commuter({required this.id, required this.name, required this.email, required this.role, this.phone});

  factory Commuter.fromJson(Map<String, dynamic> json) {
    return Commuter(
      id: json['ID'],
      name: json['name'],
      email: json['email'],
      role: json['role'],
      phone: json['phone'],
    );
  }
}