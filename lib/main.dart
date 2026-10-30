import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const apiUrl = String.fromEnvironment('API_URL', defaultValue: '');
const tracks = ['آداب وفلسفة','لغات أجنبية','علوم تجريبية','رياضيات','تقني رياضي','تسيير واقتصاد'];
const subjects = ['الفلسفة','اللغة العربية وآدابها','التاريخ','الجغرافيا','العلوم الإسلامية','اللغة الفرنسية','اللغة الإنجليزية','الرياضيات','مادة أخرى'];
void main() => runApp(const SofyanApp());

class Api {
  static Uri url(String path) {
    if (apiUrl.isEmpty) throw Exception('عنوان الخادم غير مضبوط. أضف API_URL عند بناء التطبيق.');
    return Uri.parse('$apiUrl$path');
  }
  static dynamic parse(http.Response r) {
    dynamic data;
    try { data = jsonDecode(utf8.decode(r.bodyBytes)); } catch (_) { throw Exception('استجابة غير صالحة من الخادم (${r.statusCode})'); }
    if (r.statusCode >= 400) throw Exception(data is Map ? '${data['detail'] ?? 'خطأ الخادم'}' : 'خطأ ${r.statusCode}');
    return data;
  }
  static Future<dynamic> get(String path) async => parse(await http.get(url(path)).timeout(const Duration(seconds: 30)));
  static Future<dynamic> post(String path, [Map<String,dynamic>? data]) async => parse(await http.post(url(path), headers: {'Content-Type':'application/json'},body:jsonEncode(data ?? {})).timeout(const Duration(minutes: 3)));
  static Future<dynamic> ocr(List<XFile> images) async {
    final req = http.MultipartRequest('POST',url('/api/ocr'));
    for (final f in images) { req.files.add(http.MultipartFile.fromBytes('files',await f.readAsBytes(),filename:f.name)); }
    final streamed = await req.send().timeout(const Duration(minutes: 3));
    return parse(await http.Response.fromStream(streamed));
  }
}

class SofyanApp extends StatefulWidget { const SofyanApp({super.key}); @override State<SofyanApp> createState()=>_SofyanAppState(); }
class _SofyanAppState extends State<SofyanApp> {
 bool dark = true;
 @override Widget build(BuildContext context) => MaterialApp(
  title:'SOFYAN YT',debugShowCheckedModeBanner:false,
  locale:const Locale('ar'),
  themeMode:dark?ThemeMode.dark:ThemeMode.light,
  theme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF6D5EF9)),useMaterial3:true),
  darkTheme:ThemeData(colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xFF6D5EF9),brightness:Brightness.dark),scaffoldBackgroundColor:const Color(0xFF0B1220),useMaterial3:true),
  home:Home(onTheme:()=>setState(()=>dark=!dark)));
}

class Home extends StatefulWidget { final VoidCallback onTheme; const Home({super.key,required this.onTheme}); @override State<Home> createState()=>_HomeState(); }
class _HomeState extends State<Home> {
 int tab=0; final question=TextEditingController(); final chat=TextEditingController();
 String track=tracks.first,subject=subjects.first,mode='model',status='',answer='',review='',notice='';
 int? answerId; bool busy=false; List<XFile> images=[]; List<dynamic> rows=[];
 @override void dispose(){question.dispose();chat.dispose();super.dispose();}
 Future<void> run(String label,Future<void> Function() job) async {
  setState((){busy=true;status=label;});
  try {await job();}catch(e){if(mounted)show(e.toString());}finally{if(mounted)setState((){busy=false;status='';});}
 }
 void show(String s){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s),duration:const Duration(seconds:5)));}
 Future<void> pickCamera() async {final f=await ImagePicker().pickImage(source:ImageSource.camera,imageQuality:85);if(f!=null)setState(()=>images=[...images,f].take(8).toList());}
 Future<void> pickFiles() async {
  final result=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['png','jpg','jpeg','webp','pdf'],allowMultiple:true,withData:true);
  if(result==null)return;
  final files=result.files.where((f)=>f.bytes!=null).map((f)=>XFile.fromData(f.bytes!,name:f.name,mimeType:f.extension=='pdf'?'application/pdf':'image/${f.extension}')).toList();
  setState(()=>images=[...images,...files].take(8).toList());
 }
 Future<void> extract() => run('استخراج الأسئلة…',() async {
  final r=await Api.ocr(images);setState((){question.text='${r['text']??''}';notice='${r['warning']??'راجع النص المستخرج قبل الحل.'}';});
 });
 Future<void> solve() => run('إنشاء الحل بالذكاء الاصطناعي…',() async {
  final r=await Api.post('/api/solve',{'text':question.text,'subject':subject,'track':track,'mode':mode});
  setState((){answer='${r['answer']??''}';answerId=r['id'] as int?;review='';});
 });
 Future<void> verify() => run('مراجعة الإجابة…',() async {
  final r=await Api.post('/api/verify/$answerId');setState(()=>review='${r['review']??''}');
 });
 Future<void> loadHistory() => run('تحميل السجل…',() async {final r=await Api.get('/api/history');setState(()=>rows=r as List<dynamic>);});
 Future<void> openHistory(int id) => run('فتح الحل…',() async {
  final r=await Api.get('/api/history/$id');setState((){question.text='${r['question']??''}';answer='${r['answer']??''}';review='${r['review']??''}';answerId=id;subject='${r['subject']??subjects.first}';track='${r['track']??tracks.first}';tab=0;});
 });
 Future<void> removeHistory(int id) => run('حذف الحل…',() async {
  await http.delete(Api.url('/api/history/$id'));await loadHistory();
 });
 Future<void> exportPdf() async {
  final doc=pw.Document();
  final font=await PdfGoogleFonts.cairoRegular();final bold=await PdfGoogleFonts.cairoBold();
  doc.addPage(pw.MultiPage(textDirection:pw.TextDirection.rtl,theme:pw.ThemeData.withFont(base:font,bold:bold),build:(ctx)=>[
    pw.Header(level:0,child:pw.Text('SOFYAN YT — $subject',style:pw.TextStyle(font:bold,fontSize:18))),
    pw.Text('السنة الثالثة ثانوي — $track'),pw.SizedBox(height:12),pw.Text(answer),
    if(review.isNotEmpty)...[pw.SizedBox(height:16),pw.Text('مراجعة الإجابة',style:pw.TextStyle(font:bold)),pw.Text(review)]
  ]));
  await Printing.layoutPdf(onLayout:(_)=>doc.save());
 }
 Widget tile(String title,IconData icon,VoidCallback click)=>Card(child:ListTile(leading:Icon(icon,color:const Color(0xFF9C86FF)),title:Text(title),trailing:const Icon(Icons.chevron_left),onTap:click));
 Widget input(String label,TextEditingController ctrl,{int lines=5})=>TextField(controller:ctrl,maxLines:lines,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder(),alignLabelWithHint:true));
 Widget button(String label,VoidCallback? cb,{IconData icon=Icons.auto_awesome})=>Padding(padding:const EdgeInsets.symmetric(vertical:4),child:FilledButton.icon(onPressed:busy?null:cb,icon:Icon(icon),label:Text(label)));
 Widget dropdown(String label,List<String> values,String value,ValueChanged<String?> change)=>DropdownButtonFormField<String>(value:values.contains(value)?value:values.first,isExpanded:true,decoration:InputDecoration(labelText:label,border:const OutlineInputBorder()),items:values.map((s)=>DropdownMenuItem(value:s,child:Text(s,overflow:TextOverflow.ellipsis))).toList(),onChanged:change);
 Widget solver()=>ListView(padding:const EdgeInsets.all(16),children:[
  const Text('حل الاختبارات بالذكاء الاصطناعي',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),const SizedBox(height:12),
  Wrap(spacing:8,children:[button('الكاميرا',pickCamera,icon:Icons.camera_alt),button('الصور أو PDF',pickFiles,icon:Icons.upload_file)]),
  if(images.isNotEmpty)...[Text('الملفات المختارة: ${images.map((f)=>f.name).join('، ')}'),TextButton(onPressed:()=>setState(()=>images=[]),child:const Text('مسح الملفات')),button('استخراج النص',extract,icon:Icons.document_scanner)],
  if(notice.isNotEmpty)Text(notice,style:const TextStyle(color:Colors.amber)),const SizedBox(height:12),input('نص الاختبار — يمكنك تعديله',question,lines:8),const SizedBox(height:12),
  dropdown('الشعبة',tracks,track,(v)=>setState(()=>track=v!)),const SizedBox(height:10),dropdown('المادة',subjects,subject,(v)=>setState(()=>subject=v!)),
  const SizedBox(height:10),SegmentedButton<String>(segments:const [ButtonSegment(value:'model',label:Text('نموذجية')),ButtonSegment(value:'teacher',label:Text('شرح'))],selected:{mode},onSelectionChanged:(v)=>setState(()=>mode=v.first)),
  button('حل الاختبار',question.text.trim().length<5?null:solve),
  if(answer.isNotEmpty)...[const Divider(height:32),const Text('الإجابة',style:TextStyle(fontSize:21,fontWeight:FontWeight.bold)),SelectableText(answer,style:const TextStyle(height:1.8)),
    if(review.isNotEmpty)...[const Divider(),const Text('نتيجة المراجعة',style:TextStyle(fontWeight:FontWeight.bold)),SelectableText(review)],
    Wrap(spacing:8,children:[button('إعادة التحقق',answerId==null?null:verify,icon:Icons.verified),button('تصدير PDF',exportPdf,icon:Icons.picture_as_pdf)])]
 ]);
 Widget philosophy()=>ListView(padding:const EdgeInsets.all(16),children:[const Text('الفلسفة — السنة الثالثة ثانوي',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),const SizedBox(height:10),
  for(final kind in ['تحليل نص فلسفي','مقالة جدلية','الاستقصاء بالوضع','الاستقصاء بالرفع'])tile(kind,Icons.psychology,(){setState((){tab=0;subject='الفلسفة';question.text='المنهجية المطلوبة: $kind\nالموضوع أو النص:\n';});})]);
 Widget tutor()=>ListView(padding:const EdgeInsets.all(16),children:[const Text('الأستاذ الذكي',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),const SizedBox(height:12),input('اكتب سؤالك الدراسي',chat,lines:7),button('إرسال إلى المساعد',(){setState((){question.text=chat.text;mode='teacher';tab=0;});solve();},icon:Icons.send),const Text('يعتمد على نفس خادم حل الأسئلة؛ ليس نظام محادثة متعدد الرسائل بعد.')]);
 Widget library()=>ListView(padding:const EdgeInsets.all(16),children:[const Text('مكتبة البكالوريا',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),const SizedBox(height:16),const Text('لا توجد وثائق معتمدة محملة بعد. يحتاج هذا القسم إلى مصادر قانونية موثوقة ونظام RAG على الخادم.')]);
 Widget history()=>ListView(padding:const EdgeInsets.all(16),children:[button('تحديث السجل',loadHistory,icon:Icons.refresh),for(final r in rows)tile('${r['subject']} — ${r['track']} (#${r['id']})',Icons.history,()=>openHistory(r['id'] as int))]);
 @override Widget build(BuildContext context)=>Directionality(textDirection:TextDirection.rtl,child:Scaffold(
  appBar:AppBar(title:const Text('SOFYAN YT',style:TextStyle(fontWeight:FontWeight.w900)),actions:[IconButton(onPressed:widget.onTheme,icon:const Icon(Icons.brightness_6))]),
  body:Column(children:[if(busy)const LinearProgressIndicator(),if(status.isNotEmpty)Padding(padding:const EdgeInsets.all(8),child:Text(status)),Expanded(child:IndexedStack(index:tab,children:[solver(),philosophy(),tutor(),library(),history()]))]),
  bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i){setState(()=>tab=i);if(i==4)loadHistory();},destinations:const [NavigationDestination(icon:Icon(Icons.document_scanner),label:'الاختبارات'),NavigationDestination(icon:Icon(Icons.psychology),label:'الفلسفة'),NavigationDestination(icon:Icon(Icons.smart_toy),label:'المساعد'),NavigationDestination(icon:Icon(Icons.menu_book),label:'المكتبة'),NavigationDestination(icon:Icon(Icons.history),label:'السجل')]),
  ));
}