class Data {
  static final Data _data = new Data._internal();
  int mod_id = 0;
  bool info_check = false;
  String info = "";
  
  factory Data() {
    return _data;
  }
  Data._internal();
}
final data = Data();