import 'dart:io' show Platform;

import 'package:app_template/core/ui/app_snackbar.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:permission_handler/permission_handler.dart';

enum GalleryAccessResult {
  granted,
  denied,
  permanentlyDenied,
}

class GalleryPermission {
  GalleryPermission._();

  static Future<GalleryAccessResult> requestAccess() async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      return GalleryAccessResult.granted;
    }

    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      if (status.isGranted || status.isLimited) {
        return GalleryAccessResult.granted;
      }
      if (status.isPermanentlyDenied) {
        return GalleryAccessResult.permanentlyDenied;
      }
      return GalleryAccessResult.denied;
    }

    var photosStatus = await Permission.photos.status;
    if (!photosStatus.isGranted) {
      photosStatus = await Permission.photos.request();
    }
    if (photosStatus.isGranted) {
      return GalleryAccessResult.granted;
    }
    if (photosStatus.isPermanentlyDenied) {
      return GalleryAccessResult.permanentlyDenied;
    }

    var storageStatus = await Permission.storage.status;
    if (!storageStatus.isGranted) {
      storageStatus = await Permission.storage.request();
    }
    if (storageStatus.isGranted) {
      return GalleryAccessResult.granted;
    }
    if (storageStatus.isPermanentlyDenied) {
      return GalleryAccessResult.permanentlyDenied;
    }

    return GalleryAccessResult.denied;
  }

  static Future<bool> ensureAccessWithFeedback(BuildContext context) async {
    final result = await requestAccess();
    if (result == GalleryAccessResult.granted) {
      return true;
    }
    if (!context.mounted) return false;

    if (result == GalleryAccessResult.permanentlyDenied) {
      AppSnackbar.showError(
        context,
        'Нет доступа к галерее. Разрешите доступ в настройках приложения.',
      );
      await openAppSettings();
    } else {
      AppSnackbar.showError(context, 'Нет доступа к галерее');
    }
    return false;
  }
}
