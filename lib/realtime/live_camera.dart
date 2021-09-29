import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'bounding_box.dart';
import 'camera.dart';
import 'dart:math' as math;
import 'package:tflite/tflite.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'bus_data.dart';
import 'processor.dart';

import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class LiveFeed extends StatefulWidget {
  final List<CameraDescription> cameras;
  LiveFeed(this.cameras);
  @override
  _LiveFeedState createState() => _LiveFeedState();
}

class _LiveFeedState extends State<LiveFeed> {
  List<dynamic> _recognitions;
  int _imageHeight = 0;
  int _imageWidth = 0;
  String _text = "";
  String current_mode = "Normal Mod";

  bool _hasSpeech = false;
  double level = 0.0;
  double minSoundLevel = 50000;
  double maxSoundLevel = -50000;
  String lastWords = '';
  String lastError = '';
  String lastStatus = '';
  String _currentLocaleId = '';
  int resultListened = 0;
  List<LocaleName> _localeNames = [];
  final SpeechToText speech = SpeechToText();
  TextProcessor TP = TextProcessor();

  Future<void> initSpeechState() async {
    var hasSpeech = await speech.initialize(
        onError: errorListener,
        onStatus: statusListener,
        debugLogging: true,
        finalTimeout: Duration(milliseconds: 0));
    if (hasSpeech) {
      _localeNames = await speech.locales();

      var systemLocale = await speech.systemLocale();
      _currentLocaleId = systemLocale?.localeId ?? '';
    }
    if (!mounted) return;

    setState(() {
      _hasSpeech = hasSpeech;
    });
  }

  initCameras() async {}
  loadTfModel() async {
    await Tflite.loadModel(
      model: "assets/models/ssd_mobilenet.tflite",
      labels: "assets/models/labels.txt",
    );
  }

  /* 
  The set recognitions function assigns the values of recognitions, imageHeight and width to the variables defined here as callback
  */
  setRecognitions(recognitions, imageHeight, imageWidth, text) {
    setState(() {
      _recognitions = recognitions;
      _imageHeight = imageHeight;
      _imageWidth = imageWidth;
      _text = text;
    });
  }

  void errorListener(SpeechRecognitionError error) {
    // print("Received error status: $error, listening: ${speech.isListening}");
    setState(() {
      lastError = '${error.errorMsg} - ${error.permanent}';
    });
  }

  void statusListener(String status) {
    // print(
    // 'Received listener status: $status, listening: ${speech.isListening}');
    setState(() {
      lastStatus = '$status';
    });
  }

  void startListening() {
    lastWords = '';
    lastError = '';
    speech.listen(
        onResult: resultListener,
        listenFor: Duration(seconds: 30),
        pauseFor: Duration(seconds: 5),
        partialResults: true,
        localeId: _currentLocaleId,
        onSoundLevelChange: soundLevelListener,
        cancelOnError: true,
        listenMode: ListenMode.confirmation);
    setState(() {});
  }

  void resultListener(SpeechRecognitionResult result) {
    ++resultListened;
    print('Result listener $resultListened');
    setState(() {
      lastWords = '${result.recognizedWords} - ${result.finalResult}';
      print(lastWords);
      String mod = TP.modeCheck(lastWords);
      print(mod);
      if (mod != "False" && !speech.isListening){
        setState(() {
          if(mod == "otobüs modu"){
            data.info_check = true;
            data.mod_id = 1;
            current_mode = "Otobüs Modu";
            data.info = "Otobüs Modu Açık";
          }else if(mod == "normal mod"){
            data.info_check = true;
            data.mod_id = 0;
            current_mode = "Normal Mod";
            data.info = "Normal Mod Açık";
          }else if (mod == "nesne tanıma modu"){
            data.info_check = true;
            data.mod_id = 2;
            current_mode = "Nesne Tanıma Modu";
            data.info = "Nesne Tanıma Modu Açık";
          }
          else if(mod == "Ahmet'i ara"){
            data.info_check = true;
            data.info = "Ahmet'i ara";
          }
        });
      }
    });
  }

  void soundLevelListener(double level) {
    minSoundLevel = math.min(minSoundLevel, level);
    maxSoundLevel = math.max(maxSoundLevel, level);
    // print("sound level $level: $minSoundLevel - $maxSoundLevel ");
    setState(() {
      this.level = level;
    });
  }

  void stopListening() {
    speech.stop();
    setState(() {
      level = 0.0;
    });
  }

  void cancelListening() {
    speech.cancel();
    setState(() {
      level = 0.0;
    });
  }

  @override
  void initState() {
    super.initState();
    loadTfModel();
    initSpeechState();
  }

  @override
  Widget build(BuildContext context) {
    Size screen = MediaQuery.of(context).size;
    screen = Size(480.0, 640.0);
    return Scaffold(
      appBar: AppBar(
        title: Text("Let See"),
      ),
      body: Stack(
        children: <Widget>[
          CameraFeed(widget.cameras, setRecognitions),
          BoundingBox(
            _recognitions == null ? [] : _recognitions,
            math.max(_imageHeight, _imageWidth),
            math.min(_imageHeight, _imageWidth),
            screen.height,
            screen.width,
          ),
          Container(
            alignment: Alignment.bottomCenter,
            padding: EdgeInsets.fromLTRB(0, 0, 0, 50),
            child: AutoSizeText(
              _text,
              style: TextStyle(color: Colors.red, fontSize: 30),
              textAlign: TextAlign.center,
              maxLines: 3,
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              primary: Colors.blue,
              onSurface: Colors.red,
            ),
            onPressed: () {
              if (speech.isListening) {
                stopListening();
              } else {
                startListening();
              }
            },
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Text(current_mode,
                  style: TextStyle(fontSize: 20.0),
                  textAlign: TextAlign.center),
            ),
          )
        ],
      ),
    );
  }
}
