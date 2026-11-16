# Route planning

Home opens the walking route planner. Tap the map once for a start point and
again for a finish point, request one route preview, name it, and save it to the
local SQLite database. Map tiles come from OpenFreeMap; route geometry comes
from OpenRouteService only when **Find walking route** is pressed. The saved
geometry remains available offline.

An OpenRouteService API key is required for route lookup. For local development:

```sh
flutter run --dart-define=ORS_API_KEY=your_key
```

Keep the key out of source control. A key included in a client app can be
extracted from its build, so a production release should use a server proxy or
an appropriately restricted key. With no key, the planner still opens but
route lookup is disabled.

This screen saves planned routes. Selection and overlay during a run belong to
the follow-route phase.
