import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_example/classifier_model.dart';


class ViewModel {
  ClassifierModel _classifierModel;
  File _image;
  final StreamController<File> _imagePickerController = StreamController<File>.broadcast();
  final StreamController<List> _classifierController = StreamController<List>.broadcast();
  
  Stream<File> get imagePickerStream => _imagePickerController.stream;
  Stream<List> get classifierStream => _classifierController.stream;
 
  Future init() async {
    _classifierModel = ClassifierModel(
      modelPath: "assets/mobilenet_v1_1.0_224.tflite",
      labelPath: "assets/mobilenet_v1_1.0_224.txt"
    );

    await _classifierModel.init();
    print("View model initialization finished");
    imagePickerStream.listen((file){
      run(file);
    });
  }

  Future processCameraImage() async{
    _image = await ImagePicker.pickImage(source: ImageSource.camera);
    _imagePickerController.sink.add(_image);
  }

  Future processGalleryImage() async{
    _image = await ImagePicker.pickImage(source: ImageSource.gallery);
    _imagePickerController.sink.add(_image);
  }

  Future run(File imageFile) async {
    _classifierController.sink.add(null);
    var recognitions = await _classifierModel.run(
      imageFile: imageFile,
      imageMean: 127.5,
      imageStd: 127.5,
      numResults: 3,
      threshold: 0.05,
    );
    print("Output type: " + recognitions.runtimeType.toString());
    print("Output length ${recognitions.length}");
    _classifierController.sink.add(recognitions);

  }

 

  close(){
    _imagePickerController?.close();
    _classifierController?.close();
    _classifierModel.close();
  }



}