import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite/tflite.dart';
import 'package:tflite_example/view_model.dart';

void main() => runApp(App());

class App extends StatelessWidget {
  @override
  Widget build(BuildContext context){
    return MaterialApp(
      title: 'Tflite Demo',
      theme: ThemeData(
        primarySwatch: Colors.lightGreen,
      ),
      home: HomePage(title: 'Tflite demo home page'),
  );
  }
  
}

class HomePage extends StatefulWidget {

  HomePage({Key key, this.title}): super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<HomePage> {
  
  ViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ViewModel();
    _viewModel.init();
  }

  @override
  void dispose(){
    _viewModel.close();
    super.dispose();
  }

  Widget takePhotoButton(bool isCamera){
    return Expanded(
      child: RaisedButton(
        child: isCamera ? 
          Text("Camera", style: TextStyle(fontSize: 20.0)) :
          Text("Photos", style: TextStyle(fontSize: 20.0)),
          color: Theme.of(context).primaryColor,
          onPressed: isCamera ? _viewModel.processCameraImage
                      : _viewModel.processGalleryImage,

      )
    );
  }

  Widget showRecognitions(){
    return ConstrainedBox(
      constraints: BoxConstraints.expand(height: 120.0),
      child: StreamBuilder(
        stream: _viewModel.classifierStream,
        builder: (BuildContext context, AsyncSnapshot<List> snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: snapshot.data == null ? [] : 
            snapshot.data.map((res){
              return Text(
                  "${res["index"]} - ${res["label"]}: ${res["confidence"].toStringAsFixed(3)}",
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20.0,
                    //background: Paint()..color = Colors.white,
                    ),
                  );
          }).toList(),
        );

      }
    ),
  );
}

  Widget showPhoto(){
    return Expanded(
      child: Center(
        child: StreamBuilder(
          stream: _viewModel.imagePickerStream,
          initialData: null,
          builder: (BuildContext context, AsyncSnapshot<File> snapshot){
            return snapshot.data == null ? Text('No image selected.')
              : Image.file(snapshot.data);
          },
        ),
      ),
    );
  }

  Widget _buildButtons(){
    return ConstrainedBox(
      constraints: BoxConstraints.expand(height: 80.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: <Widget>[
          takePhotoButton(false),
          takePhotoButton(true),        
    ]));
  }


Widget _buildMainWidget(){
  return Column(
    children: <Widget> [
      showPhoto(),
      showRecognitions(),
      _buildButtons(),
    ]
  );
}

Widget _busyToProcessImage(){
  return StreamBuilder(
     stream: _viewModel.classifierStream,
      builder: (BuildContext context, AsyncSnapshot<List> snapshot){
        return snapshot.data == null ? Center(child: CircularProgressIndicator()) : Text("Results:");
      }
  );
}
  

  @override
  Widget build(BuildContext context) {
    List<Widget> stackChildren = [];
    stackChildren.add(_buildMainWidget());
    stackChildren.add(_busyToProcessImage());
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Tflite demo app'),
          backgroundColor: Theme.of(context).primaryColor,
        ),
        body: Center(
          child: Stack(
            children: stackChildren,
          ),
        ),
      ),
    );
  }
}
