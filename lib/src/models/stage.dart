// lib/src/models/stage_model.dart

class StageModel {
  final String name;
  final double lat;
  final double lng;
  final int seq;

  StageModel({
    required this.name,
    required this.lat,
    required this.lng,
    required this.seq,
  });

  // This method converts the StageModel object into a Map
  // that can be directly encoded into JSON to match your Go backend.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'lat': lat,
      'lng': lng,
      'seq': seq,
    };
  }

  // Optional: A factory constructor to create a StageModel from a JSON map,
  // useful if you ever need to receive Stage data from your backend.
  factory StageModel.fromJson(Map<String, dynamic> json) {
    return StageModel(
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(), // Use num to handle int or double from JSON
      lng: (json['lng'] as num).toDouble(),
      seq: json['seq'] as int,
    );
  }
}