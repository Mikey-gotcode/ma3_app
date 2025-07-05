import 'package:latlong2/latlong.dart'; // Import LatLng
import 'dart:convert'; // Import for jsonEncode



// --- Outer wrapper for the API response ---
class CommuterRouteApiResponse {
  final List<RouteData> data;
  final bool isComposite;

  CommuterRouteApiResponse({
    required this.data,
    required this.isComposite,
  });

  factory CommuterRouteApiResponse.fromJson(Map<String, dynamic> json) {
    List<dynamic> dataList = json['data'] ?? [];
    List<RouteData> parsedRoutes = dataList.map((i) => RouteData.fromJson(i)).toList();

    return CommuterRouteApiResponse(
      data: parsedRoutes,
      isComposite: json['is_composite'] ?? false,
    );
  }
}

class RouteData {
  final int id;
  final String name;
  final String description;
  final String geometry; // Still keep it, even if we don't parse it directly for now
  final List<Stage> stages;
  final bool isComposite; // New field from backend response

  RouteData({
    required this.id,
    required this.name,
    required this.description,
    required this.geometry,
    required this.stages,
    required this.isComposite,
  });

  factory RouteData.fromJson(Map<String, dynamic> json) {
    // FIX: Safely handle null 'stages' by providing an empty list if it's null.
    // We cast to List? first to allow for null, then use ?? []
    List<dynamic>? stagesList = json['stages'];
    List<Stage> parsedStages = (stagesList ?? []).map((i) => Stage.fromJson(i)).toList();

    // Check for 'id' first, then 'ID'
    final int? routeId = (json['id'] as int?) ?? (json['ID'] as int?);

    return RouteData(
      id: routeId ?? 0,
      name: json['name'],
      description: json['description']?? '',
      geometry: json['geometry'] as String? ?? '',
      stages: parsedStages,
      isComposite: json['is_composite'] ?? false, // Handle new field
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

     final int? idValue = (json['id'] as int?) ?? (json['ID'] as int?);
     return Stage(
      id: idValue ?? 0, // **FIX: Handle null 'ID'**
      name: json['name'] ?? '', // **FIX: Handle null 'name'**
      seq: json['seq'] ?? 0, // **FIX: Handle null 'seq'**
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0, // **FIX: Handle null 'lat' and ensure double**
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0, // **FIX: Handle null 'lng' and ensure double**
    );
  }

  LatLng toLatLng() {
    return LatLng(lat, lng);
  }

  
}