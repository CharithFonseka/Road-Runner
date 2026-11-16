# Route planning

The planner has explicit Start and End point selectors. Either point can come
from a map tap, Photon/OpenStreetMap place search, or **Use my location**. A
foreground location fix is requested only after the user taps that control;
location permission is requested when needed. It automatically requests a walking route along
roads and paths. Without an OpenRouteService key it uses the public OSRM route
service. The map uses OpenFreeMap tiles.

Current weather appears for the selected start area when available. The user
can name and save a planned route locally. **Save & start run** saves the route
and begins GPS recording through the app's permission flow; the live map shows
the planned path alongside the recorded path. **Start run** works before a
route is planned.

An optional OpenRouteService key can be supplied for local development:

```sh
flutter run --dart-define=ORS_API_KEY=your_key
```

Keep the key out of source control. A client app cannot keep an embedded key
secret, so a production release should use a proxy or a restricted key.
