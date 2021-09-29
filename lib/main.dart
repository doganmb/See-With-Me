import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'realtime/live_camera.dart';
List<CameraDescription> cameras;


Future<void> main() async {
  // initialize the cameras when the app starts
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  // running the app
  runApp(
    MaterialApp(
      home: MyApp(),
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
    )
  );
}
class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("See With Me",style: TextStyle(fontSize: 30),),
      ),
      body: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => LiveFeed(cameras),
            ),
          );
        },
        child: Center(
          child: Text("Start to See",style: TextStyle(fontSize: 50 ),)
        ),
      ),
    );
  }
}