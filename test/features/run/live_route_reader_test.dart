import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:road_runner/features/run/live_route_reader.dart';

void main() {
  test('restores accepted points from an unfinished run file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'road-runner-route-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}${Platform.pathSeparator}run.jsonl');
    await file.writeAsString(
      '''
{"v":1,"runId":"run","startedAtUtcMs":1000}
{"k":"p","seq":0,"t":1001,"lat":-33.86,"lon":151.2,"ok":true}
{"k":"p","seq":1,"t":1002,"lat":-33.87,"lon":151.3,"ok":false}
{"k":"p","seq":2,"t":1003,"lat":-33.88,"lon":151.4,"ok":true}
{"k":"p","seq":3,"lat":
'''
          .trimLeft(),
    );

    final points = await const LiveRouteReader().read(file.path);
    expect(points.map((point) => point.seq), [0, 2]);
    expect(points.last.lat, -33.88);
  });
}
