import 'package:flutter_tts/flutter_tts.dart';
import 'dart:math' as math;
import 'bus_data.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

class ResultProcessor {
  ResultProcessor() {
    setTTS();
  }
  FlutterTts flutterTts = FlutterTts();
  List<List<dynamic>> result_memory = [];
  bool speakBusy = false;
  bool warning_speakBusy = false;
  int temp_mode_id = 0;    // modlar [normal mod, otobüs modu, nesne tanıma modu]
  String text = "";
  String bus_state = "";
  int list_clear_count = 0;
  List<dynamic> filtered_results = [];
  List<double> regions = [];
  List<double> bus_regions = [];
  List<List<double>> center_cords = [];
  List<int> class_indexes = [];
  List<int> cords_indexes = [];
  List<String> locations = [
    "Solda",
    "Sol ileride",
    "İleride",
    "Sağ ileride",
    "Sağda",
    "Önünüzde",
  ]; // 0:Hemen önünde 1:Sol 2: Sol orta 3: ileri 4: sağ orta 5:sağ
  List<double> location_values = [
    0.2,
    0.4,
    0.6,
    0.8,
    1.0,
  ];
  List<String> known_classes = [
    "person",
    "bicycle",
    "motorcycle",
    "car",
    "truck",
    "traffic light",
    "bus",
    "bench"
  ];
  List<String> tr_classes = [
    "insan",
    "bisiklet",
    "motorsiklet",
    "araba",
    "kamyon",
    "trafik ışığı",
    "otobüs",
    "bank",
  ];
  List<double> class_min_w = [
    0.15, // person
    0.16, //bicycle
    0.18, // motorcycle
    0.20, // car
    0.25, // truck
    0.15, // traffic light
    0.15, // bus
    0.18, //bench
  ];
  List<double> class_min_h = [
    0.20, // person
    0.16, //bicycle
    0.18, // motorcycle
    0.20, // car
    0.25, // truck
    0.15, // traffic light
    0.20, // bus
    0.18, //bench
  ];
  List<double> class_max_w = [
    0.6, // person
    0.65, //bicycle
    0.68, // motorcycle
    0.70, // car
    0.72, // truck
    0.50, // traffic light
    0.70, // bus
    0.68, //bench
  ];
  List<double> class_min_region = [
    0.5,
  ];
  List<double> class_max_region = [
    0.4, // person
    0.5, //bicycle
    0.6, // motorcycle
    0.6, // car
    0.6, // truck
    0.4, // traffic light
    0.65, // bus
    0.4, //bench
  ];

  void setTTS() async {
    await flutterTts.setLanguage("tr-TR");
    await flutterTts.setSpeechRate(1.0);
    await flutterTts.setVolume(0.5);
    await flutterTts.setPitch(1.0);
  }

  Future _speak(String text, {int time=3}) async {
    speakBusy = true;
    var result = await flutterTts.speak(text);
    await Future.delayed(Duration(seconds: time));
    speakBusy = false;
  }

  Future warn_speak(String text) async {
    warning_speakBusy = true;
    var result = await flutterTts.speak(text);
    await Future.delayed(Duration(seconds: 2));
    warning_speakBusy = false;
  }

  List<dynamic> desider(List<dynamic> results) {
    // sağ sol insan / araç tespiti tespiti
    //

    /*
  [{rect: {w: 0.38757678866386414, x: 0.31825879216194153, h: 0.4329199492931366, y: 0.17841270565986633}, confidenceInClass: 0.62109375, detectedClass: chair}, {rect: {w: 0.5819681286811829, x: 0.04512453079223633, h: 0.466443806886673, y: 0.49512287974357605}, confidenceInClass: 0.5859375, detectedClass: bed}, {rect: {w: 0.6022346019744873, x: 0.17516550421714783, h: 0.5927907228469849, y: 0.17473670840263367}, confidenceInClass: 0.40234375, detectedClass: chair}]
  
  alan kontrolü 
  genişlik kontrolü
  iç içe olma kontrolü
  merkez koordinat nokta bulma
  değerleri depolama
  bir önceki değerlere göre yaklaşıp uzaklaşma tahmini

  
  */
    filtered_results = [];
    regions = [];
    center_cords = [];
    class_indexes = [];
    cords_indexes = [];
    text = "";

    if (data.info_check){
      if (data.mod_id != temp_mode_id){
        if (data.mod_id == 1){
          text = "Otobüs Modu Açıldı";
          _speak(text);
        }
        else if (data.mod_id == 0){
          text = "Normal Mod Açıldı";
          _speak(text);
        }else if(data.mod_id == 2){
          text = "Nesne Tanıma Modu Açıldı";
          _speak(text);
        }
        temp_mode_id = data.mod_id;
      }else{
        if (data.info == "Ahmet'i ara"){
          _speak("Ahmet aranıyor.");
          FlutterPhoneDirectCaller.callNumber("05064401261");
        }else{
          _speak(data.info);
        }
      }
      data.info_check = false;
    }
    
    if (data.mod_id == 1) {
      for (var result in results) {
        String class_name = result["detectedClass"];
        int class_index = known_classes.indexWhere((f) => f == class_name);
        list_clear_count = list_clear_count + 1;
        if (list_clear_count > 4){
          bus_regions = [];
        }
        if (class_index != 6) {
          continue;
        }
        double w = result["rect"]["w"];
        if (w < class_min_w[class_index]) {
          continue;
        }
        double h = result["rect"]["h"];
        list_clear_count = 0;
        bus_regions.add(region_calc(w, h));
        filtered_results.add(result);
        bus_state = bus_state_check();
        print(bus_state);
        if (bus_state == "yaklaşıyor") {
          if (!speakBusy && !warning_speakBusy) {
            text = "Otobüs Yaklaşıyor";
            _speak(text);
          }
        }
        else if(bus_state == "önünde"){
          if (!speakBusy && !warning_speakBusy) {
            text = "Otobüs Önünüzde";
            _speak(text);
          }
        }
      }
    } else if(data.mod_id == 2){
      for (var result in results) {
        String class_name = result["detectedClass"];
        double w = result["rect"]["w"];
        double h = result["rect"]["h"];
        if (w<0.75 && h<0.75){
          continue;
        }
        if (!speakBusy && !warning_speakBusy) {
          text = "Bu nesne bir " + class_name;
          _speak(text);
        }
        filtered_results.add(result);


      }
    } else if (data.mod_id == 0){
      for (var result in results) {
        String class_name = result["detectedClass"];
        final class_index = known_classes.indexWhere((f) => f == class_name);
        if (class_index == -1) {
          continue;
        }
        double w = result["rect"]["w"];
        if (w < class_min_w[class_index]) {
          continue;
        }
        double h = result["rect"]["h"];
        if (h < class_min_h[class_index]) {
          continue;
        }

        double x = result["rect"]["x"];
        double y = result["rect"]["y"];

        double iou = get_iou([
          [x, y],
          [x + w, y + h]
        ], filtered_results);
        print(iou);
        if (iou >= 0.3) {
          continue;
        }

        regions.add(region_calc(w, h));
        center_cords.add([x + w / 2, y + h / 2]);

        filtered_results.add(result);
        class_indexes.add(class_index);
        cords_indexes
            .add((center_cords[center_cords.length - 1][0] * 5).floor());
      }
      if (filtered_results.length >= 1) {
        for (var i = 0; i < filtered_results.length; i++) {
          if (regions[i] > class_max_region[class_indexes[i]]) {
            if (!warning_speakBusy) {
              text = "DİKKAT - " +
                  locations[5] +
                  " " +
                  "1" +
                  " " +
                  tr_classes[class_indexes[i]] +
                  " " +
                  "var.";
              warn_speak(text);
            }
          }
        }
        if (!speakBusy && !warning_speakBusy) {
          text = text_creator();
          _speak(text);
        }
      }
    }

    return [filtered_results, text];
  }

  double region_calc(double w, double h) {
    return (w * h);
  }

  String bus_state_check() {
    if (bus_regions.length >= 3){
      if (bus_regions.last > 0.85){
        return "önünde";
      } 
      else {
        double vector_sum = 0;
        for (int i = 0; i<bus_regions.length-1; i++){
          vector_sum = vector_sum + ((bus_regions[i+1] - bus_regions[i])/bus_regions[i])*100;
        }
        vector_sum = vector_sum;
        print(vector_sum);
        if (vector_sum > 25){
          return "yaklaşıyor";
        }
        return "";
      }
    }
  }

  String text_creator() {
    String text = "";
    List<int> uniqes = class_indexes.toSet().toList();
    for (var uniqe in uniqes) {
      String location;
      int count = class_indexes.where((e) => e == uniqe).length;
      if (count > 1) {
        location = group_location(uniqe, count);
      } else {
        int index = class_indexes.indexWhere((e) => e == uniqe);
        location = locations[cords_indexes[index]];
      }
      text = text +
          location +
          " " +
          count.toString() +
          " " +
          tr_classes[uniqe] +
          " ";
    }
    text = text + "var.";
    return text;
  }

  String group_location(int class_index, int count) {
    double center = 0;
    for (int i = 0; i < class_indexes.length; i++) {
      if (class_indexes[i] == class_index) {
        center = center + center_cords[i][0];
      }
    }
    String location = locations[((center / count) * 5).floor()];
    return location;
  }

  double get_iou(List<List<double>> cord1, List<dynamic> filtered_list) {
    for (var result in filtered_list) {
      double x = result["rect"]["x"];
      double y = result["rect"]["y"];
      double w = result["rect"]["w"];
      double h = result["rect"]["h"];
      double x_left = math.max(cord1[0][0], x);
      double y_top = math.max(cord1[0][1], y);
      double x_right = math.min(cord1[1][0], x + w);
      double y_bottom = math.min(cord1[1][1], y + h);

      if (x_right < x_left || y_bottom < y_top) {
        continue;
      }
      double intersection_area = (x_right - x_left) * (y_bottom - y_top);

      double area1 = (cord1[1][0] - cord1[0][0]) * (cord1[1][1] - cord1[0][1]);
      double area2 = w * h;

      double iou = intersection_area / (area1 + area2 - intersection_area);
      if (iou <= 0.0 || iou >= 1.0) {
        continue;
      }
      return iou;
    }
    return 0.0;
  }
}


class TextProcessor {
  List<String> modes = ["normal mod","otobüs modu", "nesne tanıma modu", "Ahmet'i ara"];
  String modeCheck(String text){
    for(var mod in modes){
      if (text.contains(mod)){
        return mod;
      }
    }
    return "False";
  }
}