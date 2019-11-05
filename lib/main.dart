import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:local_auth/local_auth.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'globals.dart';
import 'package:flutter_datetime_picker/flutter_datetime_picker.dart';

const MaterialColor white = const MaterialColor(
  0xFFFFFFFF,
  const <int, Color>{
    50: const Color(0xFFFFFFFF),
    100: const Color(0xFFFFFFFF),
    200: const Color(0xFFFFFFFF),
    300: const Color(0xFFFFFFFF),
    400: const Color(0xFFFFFFFF),
    500: const Color(0xFFFFFFFF),
    600: const Color(0xFFFFFFFF),
    700: const Color(0xFFFFFFFF),
    800: const Color(0xFFFFFFFF),
    900: const Color(0xFFFFFFFF),
  },
);

void main(){
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) {
    runApp(ThisApp());
  });
}

class ThisApp extends StatelessWidget {

  final mainColor = Colors.brown;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: mainColor,
      ),
      home: NoteList(),
    );
  }
}

class NoteList extends StatefulWidget {
  NoteListState createState() => NoteListState();
}

class NoteListState extends State {
  @override
  void initState() {
    super.initState();

    var initializationSettingsAndroid = AndroidInitializationSettings("app_icon");
    var initializationSettingsIOS = IOSInitializationSettings();
    var initializationSettings = InitializationSettings(
        initializationSettingsAndroid, initializationSettingsIOS
    );

    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }
  final mainColor = Colors.brown;

  bool authed = false;
  var fabicon = Icons.fingerprint;

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    print(directory.path);
    return directory.path+"/notes";
  }

  Future<List> lsLocal() async {
    var path = await _localPath;
    var dir;
    try{
      dir = Directory(path).listSync();
    }

    on FileSystemException catch(e){
      Directory(path).create();
      print(e);
      return [];
    }
    print(dir);
    List files = [];

    for (var file in dir) {
      files.add(file.path);
    }

    return files;
  }

  String getTitle(path) {
    return jsonDecode(File(path).readAsStringSync())["title"]; //content divider
  }

  void readAndPass(BuildContext context, String path) {
    var contents = jsonDecode(File(path).readAsStringSync());
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              NoteDisplay(false, contents["title"], contents["content"], path, contents['isPrivate'])
      ),
    );
  }

  Widget possibleTrailer(int time){
    if(time==null) return Container(height: 0, width: 0);

    if(time>DateTime.now().millisecondsSinceEpoch){
      return Icon(Icons.notifications, color: Colors.brown);
    }
    else return Icon(Icons.notifications_active, color: Colors.brown);
  }

  Widget possibleDelNot(int remTime, Map content, File file){
    if(remTime==null||remTime<DateTime.now().millisecondsSinceEpoch) return Container(height: 0, width: 0);

    String fname = file.path.split("/").last;

    int fnameint = int.parse(fname.substring(0, fname.length-4));
    fnameint = fnameint~/1000;

    return Expanded(
        child: IconButton(
          icon: Icon(Icons.notifications_off, color: Colors.brown),
          iconSize: 38.0,
          onPressed: (){
            flutterLocalNotificationsPlugin.cancel(fnameint);
            content.remove("reminder");

            String text = jsonEncode(content);

            file.writeAsStringSync(text);

            setState(() {});
          },
        )
    );
  }

  Widget fileList(List files) {
    return ListView.builder(
      itemCount: files.length, //app specific stuff
      itemBuilder: (BuildContext context, int index) {
        var content = jsonDecode(File(files[index]).readAsStringSync());
        if(!authed) if(content["isPrivate"]) return Container(height: 0, width: 0);

        int remTime = null;

        if(content.containsKey("reminder")) remTime = content["reminder"];
        Widget title = Text(
          content['title'],
          style: TextStyle(
            fontSize: 20,
          ),
        );

        return Padding(
          padding: EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: mainColor, width: 2.0),
              borderRadius: BorderRadius.all(Radius.circular(10.0))
            ),
            child: ListTile(
              title: title,
              trailing: possibleTrailer(remTime),
              onTap:() {readAndPass(context, files[index]);},
              onLongPress: (){
                 showDialog(
                   context: context,
                   builder: (BuildContext context){
                     return AlertDialog(
                       title: Row(
                         children: <Widget>[
                           Expanded(
                             child: IconButton(
                                 icon: Icon(Icons.delete, color: Colors.brown),
                                 iconSize: 38.0,
                                 onPressed:() {
                                   File file = File(files[index]);
                                   file.deleteSync();
                                   setState(() {});
                                   Navigator.of(context).pop();
                                 }
                             )
                           ),
                           possibleDelNot(remTime, content, File(files[index]))
                         ],
                       )
                     );
                   }
                 );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> auth() async{
   //
    bool authenticated = false;
    try{
      var localAuth = new LocalAuthentication();

      authenticated = await localAuth.authenticateWithBiometrics(
          localizedReason: "Authenticate to view your private notes",
          useErrorDialogs: true,
          stickyAuth: false
      );

      if(authenticated) setState(() {
        authed = true;
        fabicon = Icons.close;
      });
    }
    on Exception catch (e){print(e);}
  }

  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Notes"),
      ),
      body: Center(
          child: FutureBuilder(
        future: lsLocal(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          if (snapshot.hasData)
            return fileList(snapshot.data);
          else if (snapshot.hasError)
            return Text(snapshot.error.toString());
          else
            return CircularProgressIndicator();
        },
      )),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FloatingActionButton(
            onPressed:() {
              if(!authed){
                auth();
              }
              else if(authed){
                setState(() {
                  authed = false;
                  fabicon = Icons.fingerprint;
                });
              }
            },
            heroTag: "FAB 1",
            child: Icon(fabicon)
          ),
          Container(
            height: 7.0,
            width: 0.0,
          ),
          FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => NoteDisplay(true, null, null, null, false)
                ),
              );
            },
            child: Icon(Icons.add),
            heroTag: "FAB 2",
          )
        ],
      ),
    );
  }
}

class NoteDisplay extends StatefulWidget {
  bool isNew;
  String currTitle;
  String currContent;
  String currPath;
  bool isPrivate;

  //TODO: Use polymorphism and stuff
  NoteDisplay(
      bool isNew, String currTitle, String currContent, String currPath, bool isPrivate) {
    this.isNew = isNew;
    this.currTitle = currTitle;
    this.currContent = currContent;
    this.currPath = currPath;
    this.isPrivate = isPrivate;
  }

  @override
  NoteDisplayState createState() => NoteDisplayState(
      this.isNew, this.currTitle, this.currContent, this.currPath, this.isPrivate);
}

class NoteDisplayState extends State {
  //For the textFields
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  String currPath;
  bool isNew;
  bool isPrivate;

  NoteDisplayState(
      bool isNew, String currTitle, String currContent, String currPath, bool isPrivate) {
    this.isPrivate = false;
    if (!isNew) {
      this.titleController.text = currTitle;
      this.contentController.text = currContent;
      this.currPath = currPath;
      this.isPrivate = isPrivate;
    }
    this.isNew = isNew;
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    print(directory.path);
    return directory.path+"/notes";
  }

  Future save(bool isNew, String title, String content, String currPath, bool isPrivate, int newReminder) async {
    File file;

    if (this.isNew) {
      var path = await _localPath;
      var time = DateTime.now().millisecondsSinceEpoch.toString();
      this.currPath = '$path/$time.txt';
      file = File('$path/$time.txt');
    } else
      file = File(currPath);

    var filedict = {
      "title": title,
      "content": content,
      "isPrivate": isPrivate
    };

    if(!this.isNew){
      Map content = jsonDecode(file.readAsStringSync());

      if(content.containsKey("reminder")){
        if(content["reminder"]>DateTime.now().millisecondsSinceEpoch){
          filedict["reminder"] = content["reminder"];
        }
      }
    }

    if(newReminder!=null) filedict["reminder"] = newReminder;

    String text = jsonEncode(filedict);

    if(title!=''||content!=''){
      file.writeAsStringSync(text);
      this.isNew = false;
    }
  }

  void delete(String path){
    File file = File(path);
    file.delete();
  }

  Widget possibleDeleteButton(
      BuildContext context, bool isNew, String currPath) {
    if (isNew) {
      return Container(width: 0, height: 0);
    }
    else{
      return IconButton(
        icon: Icon(Icons.delete, color: Colors.white),
        onPressed: (){
          delete(currPath);
          Navigator.pop(context);
        },
      );
    }
  }

  Widget PrivacyButton() {
    Icon icon;
    if (this.isPrivate) {
      icon = Icon(Icons.lock, color: Colors.brown);
    }
    else {
      icon = Icon(Icons.lock_open, color: Colors.grey);
    }
    return IconButton(
        icon: icon,
        onPressed: () {
          setState(() {
            this.isPrivate = !this.isPrivate;
          });
        }
    );
  }

  int idGen(String ting){
    print(this.currPath);//Doesn't show the correct path
    var listthing = ting.split("/");
    /*print(listthing);
    print(listthing[listthing.length-1]);
    print(listthing[listthing.length-1].substring(0, listthing[listthing.length-1].length-4));*/
    return int.parse(listthing[listthing.length-1].substring(0, listthing[listthing.length-1].length-4));
  }

  Future<void> Schedule(String title, String fname) async{
    print(this.currPath); //Shows the correct path
    DatePicker.showDateTimePicker(context,
      onConfirm: (date){
        var androidPlatformChannelSpecifics = AndroidNotificationDetails(
            'your channel id', 'your channel name', 'your channel description',
            importance: Importance.Max, priority: Priority.High, ticker: 'ticker');
        var iOSPlatformChannelSpecifics = IOSNotificationDetails();
        var platformChannelSpecifics = NotificationDetails(
            androidPlatformChannelSpecifics, iOSPlatformChannelSpecifics);

        int id = idGen(this.currPath)~/1000;

        print(id);

        String text = title;

        if(this.isPrivate) text = "Private Note";

        flutterLocalNotificationsPlugin.schedule(id, "Reminder", text, date, platformChannelSpecifics, androidAllowWhileIdle: true);
        save(this.isNew, this.titleController.text, this.contentController.text, this.currPath, this.isPrivate, date.millisecondsSinceEpoch);
      },
      currentTime: DateTime.now(),
    );
    //var scheduletime = DateTime.now().add(Duration(seconds: 5));
  }

  @override
  Widget build(BuildContext context) {
    save(this.isNew, this.titleController.text, this.contentController.text, this.currPath, this.isPrivate, null);

    return WillPopScope(
      onWillPop: (){
        save(this.isNew, this.titleController.text,
            this.contentController.text, this.currPath, this.isPrivate, null);
        Navigator.of(context).pop(true);
      },
      child: Scaffold(
          appBar: AppBar(
            title: Text("Edit Note"),
            actions: <Widget>[
              IconButton(
                icon: Icon(Icons.notifications, ),
                onPressed: (){
                  Schedule(this.titleController.text, this.currPath);
                },
              ),
              possibleDeleteButton(context, this.isNew, this.currPath),
              IconButton(
                onPressed: () {
                  save(this.isNew, this.titleController.text,
                      this.contentController.text, this.currPath, this.isPrivate, null);
                  Navigator.pop(context);
                },
                icon: Icon(Icons.save, color: Colors.white),
              )
            ],
          ),
          //resizeToAvoidBottomPadding: false,
          body: Builder(
            builder: (BuildContext context) {
              return Padding(
                padding: EdgeInsets.all(20.0),
                child: Column(children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: titleController,
                          decoration: InputDecoration.collapsed(hintText: "Title"),
                          style: TextStyle(
                            fontSize: 28.0,
                          ),
                        ),
                      ),
                      PrivacyButton(),
                    ],
                  ),
                  Divider(color: Colors.brown),
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration.collapsed(hintText: "Content"),
                      maxLines: null,
                      controller: contentController,
                      style: TextStyle(
                        fontSize: 18.0,
                      ),
                    ),
                    flex: 8,
                  ),

                ]),
              );
            },
          ),
      ),
    );
  }
}