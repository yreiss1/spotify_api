# spotify_api

[![Workflow](https://github.com/BjoernPetersen/spotify_api/actions/workflows/workflow.yaml/badge.svg)](https://github.com/BjoernPetersen/spotify_api/actions/workflows/workflow.yaml)
[![codecov](https://codecov.io/gh/BjoernPetersen/spotify_api/branch/main/graph/badge.svg?token=c7hHoMDzxM)](https://codecov.io/gh/BjoernPetersen/spotify_api)

A Spotify Web API wrapper written in Dart.

## Alpha Notice

This project is in an alpha stage. Most notably, not all endpoints are available yet, and some response fields are not
modeled. If you are missing something in particular, feel free to
[open a new issue on GitHub](https://github.com/BjoernPetersen/spotify_api/issues).

## Usage

The main entry point to the API is the `SpotifyWebApi` class. The Dart API is organized similarly to the
[Spotify Web API reference](https://developer.spotify.com/documentation/web-api/reference/), so most endpoints are
collected in groups, e.g. `tracks` or `albums`.

```dart
import 'package:spotify_api/api.dart';

Future<void> example(AuthenticationFlow authFlow) async {
    final api = SpotifyWebApi(
        authFlow: authFlow,
    );

    // Search for tracks, albums, etc.
    final searchResult = await api.search(
        query: 'Bohemian Rhapsody',
        types: [SearchType.track],
    );

    // Look up a specific track
    final track = await api.tracks.getTrack('3z8h0TU7ReDPLIbEnYhWZb');
}
```

The `AuthenticationFlow` is expected as a given in this example. See [Authentication](#authentication) for more
information.

### Pagination

You'll often encounter responses that contain a page of some API resource, perhaps most prominently when you [search
for something](https://developer.spotify.com/documentation/web-api/reference/#/operations/search), or when you try to
[get the tracks in a playlist](https://developer.spotify.com/documentation/web-api/reference/#/operations/get-playlists-tracks).

If you want to retrieve further pages, you can use a `Paginator`, which has several convenient methods to go through the
pages:

```dart
void example(SpotifyWebApi api, Page<Track> tracks) async {
    final paginator = api.paginator(tracks);

    // Go over the items on the current page
    for (final track in paginator.currentItems()) {
        print(track.name);
    }

    // Go over the items on the next page
    final nextPage = await paginator.nextPage();
    for (final track in nextPage.currentItems()) {
        print(track.name);
    }

    // Iterate over all tracks in all pages (including the current one)
    await paginator.all().forEach((track) {
        print(track.name);
    });
}
```

## Authentication

Before you can do anything in the API, you have to think about authentication. Spotify offers
[four different OAuth flows](https://developer.spotify.com/documentation/general/guides/authorization/). The table below
shows which flows are directly supported by this library:

| Name                         | Supported |
|------------------------------|:---------:|
| Authorization code           |     ✅     |
| Authorization code with PKCE |     ⛔     |
| Client credentials           |     ✅     |
| Implicit grant               |     ⛔     |

Note that it's possible to implement an authentication flow yourself. The table above just shows the existing ones that
are ready-to-use.

You'll need to [register your app with Spotify](https://developer.spotify.com/dashboard) before you can use this
library. Spotify will give you a client ID and a client secret, the latter of which you may not need, depending on the
OAuth flow you want to use.

### Client credentials flow

This is the simplest full OAuth flow, as it only requires you client ID and your client secret and works without user
interaction. It's not possible to access any user data using this flow, though.

Example:
```dart
final api = SpotifyWebApi(
    authFlow: ClientCredentialsFlow(
        clientId: 'myclientid',
        clientSecret: 'supersecret',
    ),
);
```
