import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'package:spotify_api/src/api_models/model.dart';

part 'response.g.dart';

@immutable
@JsonSerializable(createToJson: false)
final class Artist {
  final String id;
  final String name;
  final List<String> genres;
  final List<Map> images;

  /// The popularity of the artist.
  ///
  /// The value will be between 0 and 100, with 100 being the most popular.
  ///
  /// The artist's popularity is calculated from the popularity of all the
  /// artist's tracks.
  final double? popularity;
  Artist(
      {required this.id,
      required this.name,
      required this.genres,
      required this.popularity,
      required this.images});

  factory Artist.fromJson(Json json) => _$ArtistFromJson(json);

  @override
  String toString() {
    return '$name <$id>';
  }
}

@immutable
@JsonSerializable(createToJson: false)
final class Artists {
  final List<Artist?> artists;

  Artists(this.artists);

  factory Artists.fromJson(Json json) => _$ArtistsFromJson(json);
}
