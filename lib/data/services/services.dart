// SQLite、位置、カメラなど単一の外部データ源をラップするService群。
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart' as location;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_models.dart';

/// Repositoryが利用する最小限のkey-value永続化境界。
abstract interface class DatabaseService {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> clear();
}

/// アプリ専用SQLiteへJSON文字列を保存する実装。
class SqliteDatabaseService implements DatabaseService {
  Database? _database;
  Future<Database> get _db async {
    if (_database != null) return _database!;
    final root = await getDatabasesPath();
    _database = await openDatabase(
      p.join(root, 'soba_no_inochi.db'),
      version: 1,
      onCreate: (db, _) => db.execute(
        'CREATE TABLE app_data (key TEXT PRIMARY KEY, value TEXT NOT NULL)',
      ),
    );
    return _database!;
  }

  @override
  Future<String?> read(String key) async {
    final rows = await (await _db).query(
      'app_data',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['value']! as String;
  }

  @override
  Future<void> write(String key, String value) async => (await _db).insert(
    'app_data',
    {'key': key, 'value': value},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
  @override
  Future<void> delete(String key) async =>
      (await _db).delete('app_data', where: 'key = ?', whereArgs: [key]);
  @override
  Future<void> clear() async => (await _db).delete('app_data');
}

/// 時刻をテストで差し替え可能にする境界。
abstract interface class ClockService {
  DateTime now();
}

/// 端末の現在時刻を返す実装。
class SystemClockService implements ClockService {
  const SystemClockService();
  @override
  DateTime now() => DateTime.now();
}

/// 位置権限、観測ストリーム、距離計算をまとめた端末境界。
abstract interface class LocationService {
  Future<LocationAccess> requestAccess();
  Future<Stream<GeoPoint>> startTracking();
  Future<void> stopTracking();
  double distanceBetween(GeoPoint from, GeoPoint to);
}

/// 探索中だけ端末の位置ストリームとAndroidの継続通知を有効にする実装。
class DeviceLocationService implements LocationService {
  DeviceLocationService([location.Location? client])
    : _client = client ?? location.Location.instance;

  final location.Location _client;

  @override
  Future<LocationAccess> requestAccess() async {
    if (!await _client.serviceEnabled()) {
      return LocationAccess.serviceDisabled;
    }
    var permission = await _client.hasPermission();
    if (permission == location.PermissionStatus.denied) {
      permission = await _client.requestPermission();
    }
    return switch (permission) {
      location.PermissionStatus.granted ||
      location.PermissionStatus.grantedLimited => LocationAccess.granted,
      location.PermissionStatus.deniedForever => LocationAccess.deniedForever,
      _ => LocationAccess.denied,
    };
  }

  @override
  Future<Stream<GeoPoint>> startTracking() async {
    final configured = await _client.changeSettings(
      accuracy: location.LocationAccuracy.high,
      interval: 15000,
      backgroundInterval: 15000,
      distanceFilter: 10,
    );
    if (!configured) throw StateError('位置情報の取得間隔を設定できませんでした');
    await _client.changeNotificationOptions(
      channelName: '探索中の位置記録',
      title: 'そばのいのち・探索中',
      subtitle: '探索中だけ位置を記録しています',
      description: '一時停止または終了すると位置記録も停止します',
      onTapBringToFront: true,
    );
    // ユーザー操作中に開始する位置FGSに限定し、「常に許可」は要求しない。
    final enabled = await _client.enableBackgroundMode(
      enable: true,
      requireBackgroundPermission: false,
    );
    if (!enabled || !await _client.isBackgroundModeEnabled()) {
      throw StateError('バックグラウンド位置記録を開始できませんでした');
    }
    return _client.onLocationChanged.map(
      (value) => GeoPoint(
        latitude: value.latitude,
        longitude: value.longitude,
        accuracy: value.accuracy ?? 0,
        recordedAt: value.time == null
            ? DateTime.now()
            : DateTime.fromMillisecondsSinceEpoch(value.time!.round()),
      ),
    );
  }

  @override
  Future<void> stopTracking() async {
    if (!await _client.isBackgroundModeEnabled()) return;
    await _client.enableBackgroundMode(
      enable: false,
      requireBackgroundPermission: false,
    );
    if (await _client.isBackgroundModeEnabled()) {
      throw StateError('バックグラウンド位置記録を停止できませんでした');
    }
  }

  @override
  double distanceBetween(GeoPoint from, GeoPoint to) {
    // プラグインを切り替えても集計値が変わらないよう、WGS84上の大円距離を使う。
    const earthRadiusMeters = 6371000.0;
    final fromLatitude = _degreesToRadians(from.latitude);
    final toLatitude = _degreesToRadians(to.latitude);
    final latitudeDelta = toLatitude - fromLatitude;
    final longitudeDelta = _degreesToRadians(to.longitude - from.longitude);
    final haversine =
        math.pow(math.sin(latitudeDelta / 2), 2) +
        math.cos(fromLatitude) *
            math.cos(toLatitude) *
            math.pow(math.sin(longitudeDelta / 2), 2);
    return 2 * earthRadiusMeters * math.asin(math.sqrt(haversine));
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;
}

/// 端末カメラから写真の一時パスを取得する境界。
abstract interface class CameraService {
  Future<String?> capture();
}

/// image_pickerで背面カメラを起動する実装。
class DeviceCameraService implements CameraService {
  DeviceCameraService(this._picker);
  final ImagePicker _picker;
  @override
  Future<String?> capture() async => (await _picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 92,
    preferredCameraDevice: CameraDevice.rear,
  ))?.path;
}

/// アプリ専用写真領域のパス作成と一括削除を扱う境界。
abstract interface class FileService {
  Future<String> newPhotoPath(String id);
  Future<void> deleteAllPhotos();
}

/// OSが割り当てたアプリ文書領域へ観察写真を保存する実装。
class DeviceFileService implements FileService {
  Future<Directory> get _directory async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(p.join(root.path, 'observations'));
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory;
  }

  @override
  Future<String> newPhotoPath(String id) async =>
      p.join((await _directory).path, '$id.jpg');
  @override
  Future<void> deleteAllPhotos() async {
    final directory = await _directory;
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

/// 撮影元ファイルから位置メタデータを除いた画像を作る境界。
abstract interface class ImageSanitizationService {
  Future<String> sanitize({
    required String source,
    required String destination,
  });
}

/// JPEGへ再エンコードし、EXIFを引き継がずに保存する実装。
class ReencodingImageSanitizationService implements ImageSanitizationService {
  @override
  Future<String> sanitize({
    required String source,
    required String destination,
  }) async {
    final result = await FlutterImageCompress.compressAndGetFile(
      source,
      destination,
      format: CompressFormat.jpeg,
      quality: 88,
      keepExif: false,
      autoCorrectionAngle: true,
    );
    if (result == null) throw StateError('写真を安全に保存できませんでした');
    return result.path;
  }
}

/// 観察を分類する外部AIまたはモックの境界。
abstract interface class AiClassificationService {
  Future<ClassificationStatus> classify(Observation observation);
}

/// 端末外へ送信せず、入力文から3種類の結果を返す試作用実装。
class MockAiClassificationService implements AiClassificationService {
  const MockAiClassificationService();
  @override
  Future<ClassificationStatus> classify(Observation observation) async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    final note = observation.note.toLowerCase();
    if (note.contains('対象外')) return ClassificationStatus.outside;
    if (note.contains('わからない') || note.contains('不明')) {
      return ClassificationStatus.indeterminate;
    }
    return ClassificationStatus.usable;
  }
}
