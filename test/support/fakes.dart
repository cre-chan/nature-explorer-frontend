// Provider overrideで端末依存を置き換える、決定的なテスト用Service群。
import 'dart:async';
import 'dart:io';

import 'package:soba_no_inochi/data/models/app_models.dart';
import 'package:soba_no_inochi/data/services/services.dart';

class InMemoryDatabaseService implements DatabaseService {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
  @override
  Future<void> clear() async => values.clear();
}

class FakeClockService implements ClockService {
  FakeClockService(this.value);
  DateTime value;
  void advance(Duration duration) => value = value.add(duration);
  @override
  DateTime now() => value;
}

class FakeLocationService implements LocationService {
  final controller = StreamController<GeoPoint>.broadcast();
  LocationAccess access = LocationAccess.granted;
  bool tracking = false;
  bool failToStart = false;
  bool failToStop = false;
  int startCount = 0;
  int stopCount = 0;
  void emit(GeoPoint point) => controller.add(point);
  @override
  Future<LocationAccess> requestAccess() async => access;
  @override
  Future<Stream<GeoPoint>> startTracking() async {
    if (failToStart) throw StateError('位置記録を開始できませんでした');
    startCount += 1;
    tracking = true;
    return controller.stream;
  }

  @override
  Future<void> stopTracking() async {
    if (!tracking) return;
    if (failToStop) throw StateError('位置記録を停止できませんでした');
    stopCount += 1;
    tracking = false;
  }

  @override
  double distanceBetween(GeoPoint from, GeoPoint to) => 10;
  Future<void> close() => controller.close();
}

class FakeCameraService implements CameraService {
  FakeCameraService(this.source);
  String? source;
  int captureCount = 0;
  @override
  Future<String?> capture() async {
    captureCount += 1;
    return source;
  }
}

class FakeFileService implements FileService {
  FakeFileService(this.root);
  final Directory root;
  @override
  Future<String> newPhotoPath(String id) async {
    root.createSync(recursive: true);
    return '${root.path}/$id.jpg';
  }

  @override
  Future<void> deleteAllPhotos() async {
    if (root.existsSync()) root.deleteSync(recursive: true);
  }
}

class FakeImageSanitizationService implements ImageSanitizationService {
  @override
  Future<String> sanitize({
    required String source,
    required String destination,
  }) async {
    File(source).copySync(destination);
    return destination;
  }
}

class FakeAiClassificationService implements AiClassificationService {
  FakeAiClassificationService([this.result = ClassificationStatus.usable]);
  final ClassificationStatus result;
  @override
  Future<ClassificationStatus> classify(Observation observation) async =>
      result;
}
