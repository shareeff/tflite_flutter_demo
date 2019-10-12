import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_example/classifier_model.dart';


class ViewModel {
  ClassifierModel _classifierModel;
  File _image;
  bool _isBusy = false;

  final StreamController<File> _imagePickerController = StreamController<File>.broadcast();
  final StreamController<List> _classifierController = StreamController<List>.broadcast();
  final StreamController<bool> _loadModelController = StreamController<bool>.broadcast();

  Stream<File> get imagePickerStream => _imagePickerController.stream;
  Stream<List> get classifierStream => _classifierController.stream;
  Stream<bool> get loadModelStream => _loadModelController.stream;

  Future init() async {
    _isBusy = true;
    _loadModelController.sink.add(_isBusy);
    _classifierModel = ClassifierModel(
      modelPath: "assets/mobilenet_v1_1.0_224.tflite",
      labelPath: "assets/mobilenet_v1_1.0_224.txt"
    );
    _classifierModel.init().then((val){
      _isBusy = false;
      _loadModelController.sink.add(_isBusy);
    }
    );
    //imagePickerStream.listen((file) => run(file));
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
    _classifierController.sink.add(recognitions);

  }

 

  close(){
    _imagePickerController?.close();
    _classifierController?.close();
    _loadModelController?.close();
     _classifierModel.close();
  }



}