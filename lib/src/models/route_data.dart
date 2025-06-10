import 'package:latlong2/latlong.dart'; // Import LatLng


class RouteData {
  final int id;
  final String name;
  final String description;
  final String geometry; // Still keep it, even if we don't parse it directly for now
  final List<Stage> stages;

  RouteData({
    required this.id,
    required this.name,
    required this.description,
    required this.geometry,
    required this.stages,
  });

  factory RouteData.fromJson(Map<String, dynamic> json) {
    // FIX: Safely handle null 'stages' by providing an empty list if it's null.
    // We cast to List? first to allow for null, then use ?? []
    List<dynamic>? stagesList = json['stages'];
    List<Stage> parsedStages = (stagesList ?? []).map((i) => Stage.fromJson(i)).toList();

    return RouteData(
      id: json['ID'],
      name: json['name'],
      description: json['description'],
      geometry: json['geometry'],
      stages: parsedStages,
    );
  }
}

class Stage {
  final int id;
  final String name;
  final int seq;
  final double lat;
  final double lng;

  Stage({
    required this.id,
    required this.name,
    required this.seq,
    required this.lat,
    required this.lng,
  });

  factory Stage.fromJson(Map<String, dynamic> json) {
    return Stage(
      id: json['ID'],
      name: json['name'],
      seq: json['seq'],
      lat: json['lat'],
      lng: json['lng'],
    );
  }

  LatLng toLatLng() {
    return LatLng(lat, lng);
  }
}