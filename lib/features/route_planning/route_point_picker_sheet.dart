import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_palette.dart';
import '../../data/current_location_client.dart';
import 'place_search_client.dart';

class RoutePointChoice {
  const RoutePointChoice.map() : point = null, label = null;
  const RoutePointChoice.place(this.point, this.label);

  final LatLng? point;
  final String? label;
}

/// A focused picker for one route endpoint. Search results stay visible above
/// the keyboard; selecting the map closes the sheet and leaves the map active.
class RoutePointPickerSheet extends StatefulWidget {
  const RoutePointPickerSheet({
    super.key,
    required this.isStart,
    required this.placeSearch,
    required this.biasCenter,
    this.currentLocationGetter,
  });

  final bool isStart;
  final PlaceSearchClient placeSearch;
  final LatLng biasCenter;
  final Future<LatLng?> Function()? currentLocationGetter;

  static const Key searchFieldKey = Key('routePlanning.search');
  static const Key currentLocationKey = Key('routePlanning.currentLocation');
  static const Key pickOnMapKey = Key('routePlanning.pickOnMap');

  @override
  State<RoutePointPickerSheet> createState() => _RoutePointPickerSheetState();
}

class _RoutePointPickerSheetState extends State<RoutePointPickerSheet> {
  final _search = TextEditingController();
  Timer? _debounce;
  int _request = 0;
  bool _searching = false;
  bool _locating = false;
  String? _error;
  List<PlaceSearchResult> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    setState(() {
      _request++;
      _results = const [];
      _searching = false;
      _error = null;
    });
    if (value.trim().length < 2) return;
    _debounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_runSearch(value)),
    );
  }

  Future<void> _runSearch(String value) async {
    final query = value.trim();
    if (query.length < 2) return;
    final request = ++_request;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final results = await widget.placeSearch.search(
        query,
        biasCenter: widget.biasCenter,
      );
      if (!mounted || request != _request) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _results = const [];
        _searching = false;
        _error = 'Could not search places. Try again.';
      });
    }
  }

  Future<void> _useCurrentLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final getter = widget.currentLocationGetter;
      final location = getter != null
          ? await getter()
          : await const CurrentLocationClient().currentLocation();
      if (!mounted) return;
      if (location == null) {
        setState(
          () => _error =
              'Current location unavailable. Check GPS and permission.',
        );
        return;
      }
      Navigator.of(context)
          .pop(RoutePointChoice.place(location, 'Current location'));
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Current location unavailable. Check GPS and permission.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final available =
        MediaQuery.sizeOf(context).height -
        MediaQuery.paddingOf(context).top -
        keyboard -
        24;
    final height = math.min(420.0, math.max(180.0, available));
    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.isStart ? 'Choose start' : 'Choose destination',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close point picker',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                key: RoutePointPickerSheet.searchFieldKey,
                controller: _search,
                textInputAction: TextInputAction.search,
                onChanged: _onSearchChanged,
                onSubmitted: (value) => unawaited(_runSearch(value)),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Search a place or address',
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 6),
            ListTile(
              key: RoutePointPickerSheet.currentLocationKey,
              leading: _locating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(Icons.my_location_rounded, color: palette.accent),
              title: const Text('Use my location'),
              onTap: _locating ? null : () => unawaited(_useCurrentLocation()),
            ),
            ListTile(
              key: RoutePointPickerSheet.pickOnMapKey,
              leading: Icon(Icons.touch_app_outlined, color: palette.accent),
              title: const Text('Pick on map'),
              onTap: () =>
                  Navigator.of(context).pop(const RoutePointChoice.map()),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(_error!, style: TextStyle(color: palette.error)),
              ),
            Expanded(
              child: _results.isEmpty && !_searching && _error == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _search.text.trim().length < 2
                              ? 'Search for a place, use your location, or choose a point on the map.'
                              : 'No places found. Try another name or pick on the map.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _results.length,
                      itemBuilder: (context, index) {
                        final place = _results[index];
                        return ListTile(
                          leading: const Icon(Icons.place_outlined),
                          title: Text(
                            place.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: place.subtitle.isEmpty
                              ? null
                              : Text(
                                  place.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          onTap: () => Navigator.of(context).pop(
                            RoutePointChoice.place(place.location, place.name),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
