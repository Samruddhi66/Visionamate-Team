import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Service to handle sharing VisionMate APK directly from within the app
/// with the exact name 'VisionMate.apk' instead of Android's internal 'base.apk'.
class AppShareService {
  static const MethodChannel _channel = MethodChannel('com.visionmate.visionmate/app_info');

  /// Shares the installed VisionMate APK with friendly name 'VisionMate.apk'
  static Future<bool> shareAppApk({
    Function(String status)? onStatusUpdate,
  }) async {
    try {
      if (!Platform.isAndroid) {
        onStatusUpdate?.call('Sharing VisionMate...');
        await SharePlus.instance.share(
          ShareParams(
            text: 'VisionMate - दृष्टिहीन मित्रांसाठी AI व्हिजन असिस्टंट ॲप: https://github.com/Samruddhi66/Visionamate-Team',
            subject: 'VisionMate App',
          ),
        );
        return true;
      }

      onStatusUpdate?.call('Preparing VisionMate.apk...');
      final apkPath = await _channel.invokeMethod<String>('getApkPath');
      if (apkPath == null || apkPath.isEmpty) {
        debugPrint('[AppShareService] Source APK path is null');
        return await _fallbackShareLink();
      }

      final sourceFile = File(apkPath);
      if (!sourceFile.existsSync()) {
        debugPrint('[AppShareService] Source APK does not exist at $apkPath');
        return await _fallbackShareLink();
      }

      // Copy APK to temporary cache with proper 'VisionMate.apk' filename
      final tempDir = await getTemporaryDirectory();
      final shareFolder = Directory('${tempDir.path}/app_share');
      if (!shareFolder.existsSync()) {
        shareFolder.createSync(recursive: true);
      }
      final targetApk = File('${shareFolder.path}/VisionMate.apk');

      // Efficient copy only if missing or size differs
      if (!targetApk.existsSync() || targetApk.lengthSync() != sourceFile.lengthSync()) {
        await sourceFile.copy(targetApk.path);
      }

      onStatusUpdate?.call('Sharing VisionMate.apk...');
      final xFile = XFile(
        targetApk.path,
        name: 'VisionMate.apk',
        mimeType: 'application/vnd.android.package-archive',
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [xFile],
          fileNameOverrides: ['VisionMate.apk'],
          subject: 'VisionMate.apk',
          text: 'VisionMate - दृष्टिहीन मित्रांसाठी AI व्हिजन असिस्टंट ॲप',
        ),
      );
      return true;
    } catch (e) {
      debugPrint('[AppShareService] Share failed: $e');
      return await _fallbackShareLink();
    }
  }

  static Future<bool> _fallbackShareLink() async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'VisionMate - दृष्टिहीन मित्रांसाठी AI व्हिजन असिस्टंट ॲप: https://github.com/Samruddhi66/Visionamate-Team',
          subject: 'VisionMate App',
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
