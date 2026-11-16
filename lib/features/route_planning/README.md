# Route planning

The planner offers Walk, Run, and Cycle routes. Start and Destination each open
a focused bottom picker with place search, **Use my location**, and **Pick on
map**. A foreground location fix is requested only after the user taps that
control; location permission is requested when needed. Walk and Run use
pedestrian routing; Cycle uses bicycle routing. Without an OpenRouteService key
the planner uses the public OSRM foot and bike services. The map uses OpenFreeMap
tiles.

Current weather appears for the selected start area when available. The user
can name and save a planned route locally with its activity. **Save & start
run** is offered for Run routes and begins GPS recording through the app's
permission flow; the live map shows the planned path alongside the recorded
path. **Start run** works before a route is planned. Walk and Cycle routes can
be saved, while run tracking, streaks, and badges remain tied to running.

An optional OpenRouteService key can be supplied for local development:

```sh
flutter run --dart-define=ORS_API_KEY=your_key
```

Keep the key out of source control. A client app cannot keep an embedded key
secret, so a production release should use a proxy or a restricted key.
