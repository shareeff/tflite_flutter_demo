import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Tflite {
  static const MethodChannel _channel =
      const MethodChannel('tflite');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
  static Future<String> loadModel({
    @required String modelPath,
    @required String labelPath,
    int numThreads = 1,
  }) async {
    return await _channel.invokeMethod(
      'loadModel',
      {"modelPath": modelPath, "labelPath": labelPath, "numThreads": numThreads}
    );
  }
  static Future<dynamic> runModelOnImage({
    @required String imagePath,
    double imageMean = 0,
    double imageStd = 255.0,
    int numResults = 5,
    double threshold = 0.1,
  }) async {
    return await _channel.invokeMethod(
      'runModelOnImage',
      {"imagePath": imagePath, "imageMean": imageMean, "imageStd": imageStd, "numResults": numResults, "threshold": threshold}
    );
  }

  static Future<dynamic> closeInterpreter() async {
    return await _channel.invokeMethod(
      'closeInterpreter'
    );
  }


}
