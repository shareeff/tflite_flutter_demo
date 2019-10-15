import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite/tflite.dart';



class ClassifierModel {

  String modelPath;
  String labelPath;

  ClassifierModel({
    @required this.modelPath,
    @required this.labelPath,
  }) : assert(modelPath != null),
       assert(labelPath != null);

  Future init() async {
    await loadModel(
      loadModelPath: modelPath,
      loadLabelPath: labelPath,
    );
  }
  

  Future loadModel({
    @required String loadModelPath,
    @required String loadLabelPath,
    int numThreads = 1,
  }) async {

    Tflite.closeInterpreter();
    try {
      String res = await Tflite.loadModel(
        modelPath: loadModelPath,
        labelPath: loadLabelPath,
        numThreads: numThreads,
      );
      print(res);

    } on PlatformException {
      print("Failed to load model.");
    }
  }

  Future<List> run({
    @required File imageFile,
    @required double imageMean,
    @required double imageStd,
    @required double threshold,
    int numResults = 3,
  }) async {
    var recognitions = await Tflite.runModelOnImage(
      imagePath: imageFile.path,
      imageMean: imageMean,
      imageStd: imageStd,
      numResults: numResults,
      threshold: threshold,
    );

    return recognitions.reversed.toList();

  }


 Future close() async {
   String res = await Tflite.closeInterpreter();
   print(res);
 }
}
