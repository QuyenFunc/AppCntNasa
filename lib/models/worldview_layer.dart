import 'package:json_annotation/json_annotation.dart';

part 'worldview_layer.g.dart';

@JsonSerializable()
class WorldviewLayer {
  final String id;
  final String title;
  final String description;
  final String type; // 'wmts', 'wms', etc.
  final String format; // 'image/png', 'image/jpeg'
  final String tileMatrixSet;
  final String baseUrl;
  final List<String> availableDates;
  final double opacity;
  final bool visible;
  final Map<String, dynamic>? metadata;

  const WorldviewLayer({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.format,
    required this.tileMatrixSet,
    required this.baseUrl,
    required this.availableDates,
    this.opacity = 1.0,
    this.visible = true,
    this.metadata,
  });

  factory WorldviewLayer.fromJson(Map<String, dynamic> json) =>
      _$WorldviewLayerFromJson(json);

  Map<String, dynamic> toJson() => _$WorldviewLayerToJson(this);

  WorldviewLayer copyWith({
    String? id,
    String? title,
    String? description,
    String? type,
    String? format,
    String? tileMatrixSet,
    String? baseUrl,
    List<String>? availableDates,
    double? opacity,
    bool? visible,
    Map<String, dynamic>? metadata,
  }) {
    return WorldviewLayer(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      format: format ?? this.format,
      tileMatrixSet: tileMatrixSet ?? this.tileMatrixSet,
      baseUrl: baseUrl ?? this.baseUrl,
      availableDates: availableDates ?? this.availableDates,
      opacity: opacity ?? this.opacity,
      visible: visible ?? this.visible,
      metadata: metadata ?? this.metadata,
    );
  }

  // Common Worldview layers
  static const List<WorldviewLayer> defaultLayers = [
    WorldviewLayer(
      id: 'MODIS_Terra_CorrectedReflectance_TrueColor',
      title: 'MODIS Terra True Color',
      description: 'True color imagery from MODIS Terra satellite',
      type: 'wmts',
      format: 'image/jpeg',
      tileMatrixSet: 'GoogleMapsCompatible_Level9',
      baseUrl: 'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best',
      availableDates: [],
    ),
    WorldviewLayer(
      id: 'MODIS_Aqua_CorrectedReflectance_TrueColor',
      title: 'MODIS Aqua True Color',
      description: 'True color imagery from MODIS Aqua satellite',
      type: 'wmts',
      format: 'image/jpeg',
      tileMatrixSet: 'GoogleMapsCompatible_Level9',
      baseUrl: 'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best',
      availableDates: [],
    ),
    WorldviewLayer(
      id: 'VIIRS_SNPP_CorrectedReflectance_TrueColor',
      title: 'VIIRS SNPP True Color',
      description: 'True color imagery from VIIRS SNPP satellite',
      type: 'wmts',
      format: 'image/jpeg',
      tileMatrixSet: 'GoogleMapsCompatible_Level9',
      baseUrl: 'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best',
      availableDates: [],
    ),
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorldviewLayer &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
