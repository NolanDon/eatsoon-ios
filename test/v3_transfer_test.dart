import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eatsoon/v3/brand.dart';
import 'package:eatsoon/v3/model.dart';
import 'package:eatsoon/v3/transfer.dart';
import 'package:eatsoon/v3/sharing.dart';
import 'package:eatsoon/v3/onboarding.dart';
import 'package:eatsoon/niche/ai_client.dart';
import 'package:eatsoon/experience/feedback_form.dart';
import 'v3_fixtures.dart';

void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 setUp(()=>SharedPreferences.setMockInitialValues({}));
 test('code links enforce app scope and normalize an unambiguous 16-character code',(){
   const code='ABCDEFGHIJKLMNOP';
   expect(()=>normalizeShareCode(code),throwsFormatException); // I and O are intentionally absent.
   expect(normalizeShareCode('abcd-efgh-jkmn-pqrs'),'ABCDEFGHJKMNPQRS');
   expect(normalizeShareCode('https://boxillapps.com/transfer#app=$apiAppId&code=ABCDEFGHJKMNPQRS'),'ABCDEFGHJKMNPQRS');
   expect(()=>normalizeShareCode('https://boxillapps.com/transfer#app=other&code=ABCDEFGHJKMNPQRS'),throwsFormatException);
 });
 test('image traversal rejects path escapes and rewrites nested comic images',(){
   expect(()=>sharedPhotoNames([{'photo':'../secret.jpg'}]),throwsFormatException);
   expect(sharedPhotoNames([{'photo':'original.jpg','panels':[{'image':'panel.png'}]}]),{'original.jpg','panel.png'});
   expect(replaceSharedPhotos({'panels':[{'image':'panel.png'}]},{'panel.png':'new.png'}),{'panels':[{'image':'new.png'}]});
 });
 test('atomic shared import preserves existing records, dates and remaps outfit references',()async{
   final prefs=await SharedPreferences.getInstance(),store=V3Store(appId,appKind,prefs);
   await store.addAll([fixture(appKind)]);
   final incoming=fixture(appKind,id:'shared-record');
   final pieces=[incoming,if(appKind=='clothing'){...fixture(appKind,id:'shared-bottom'),'category':'bottom'}];
   final outfits=appKind=='clothing'?[<String,dynamic>{'id':'outfit','ids':['shared-record','shared-bottom'],'date':'2026-10-14'}]:<Item>[];
   await store.mergeShared(pieces,outfits,'receipt');
   final count=store.items.length;expect(count,1+pieces.length);
   expect(store.items.first['sourceTransferId'],isNull);
   expect(store.items[1]['id'],isNot('shared-record'));
   expect(store.items[1]['nextDate'],incoming['nextDate']);
   if(appKind=='clothing')expect((store.outfits.first['ids'] as List).every((id)=>store.items.any((v)=>v['id']==id)),true);
   await store.mergeShared(pieces,outfits,'receipt');expect(store.items.length,count);
   final reopened=V3Store(appId,appKind,prefs);expect(reopened.items.length,count);
 });
 test('a rejected shared record cannot partially mutate the local collection',()async{
   final prefs=await SharedPreferences.getInstance(),store=V3Store(appId,appKind,prefs);await store.addAll([fixture(appKind)]);
   final before=store.export();
   await expectLater(store.mergeShared([{...fixture(appKind),'name':''}],[],'bad'),throwsFormatException);
   expect(store.export(),before);
 });
 test('one-use import acknowledges after commit and repeated imports stay idempotent',()async{
   final prefs=await SharedPreferences.getInstance(),store=V3Store(appId,appKind,prefs);
   await prefs.setBool('companion.attested.$apiAppId.key',true);
   final operations=<String>[];
   final api=AiClient(apiAppId,native:(method,args)async=>'key',transport:(path,body,headers)async{
     if(path.endsWith('challenge'))return {'schemaVersion':1,'nonce':'nonce','challengeId':'challenge'};
     final data=jsonDecode(body) as Map;operations.add(data['operation'] as String);
     if(data['operation']=='redeem')return {'schemaVersion':1,'manifest':{'version':1,'app':apiAppId,'kind':appKind,'items':[fixture(appKind)],'outfits':[],'files':[],'reminders':true}};
     if(data['operation']=='complete')expect(store.items.length,1);
     return {'schemaVersion':1};
   });
   final client=TransferClient(store,'',prefs,api:api);
   final first=await client.redeem('ABCDEFGHJKMNPQRS',progress:(_){ });expect(first.count,1);expect(first.reminders,true);
   final again=await client.redeem('ABCDEFGHJKMNPQRS',progress:(_){ });expect(again.count,0);expect(store.items.length,1);expect(operations.where((v)=>v=='redeem').length,1);
 });
 testWidgets('share all selects actual records and receive is available with an empty collection',(t)async{
   final prefs=await SharedPreferences.getInstance(),store=V3Store(appId,appKind,prefs);await store.addAll([fixture(appKind),{...fixture(appKind), 'name': 'Second food'}]);
   await t.pumpWidget(MaterialApp(theme:v3Theme(),home:SharingScreen(client:TransferClient(store,'',prefs),onImported:(_)async{})));await t.pumpAndSettle();
   expect(find.text('Share all 2'),findsOneWidget);await t.tap(find.text('Share all 2'));await t.pumpAndSettle();
   expect(t.widgetList<CheckboxListTile>(find.byType(CheckboxListTile)).every((v)=>v.value==true),true);
   await t.tap(find.text('Receive'));await t.pumpAndSettle();expect(find.text('Import collection'),findsOneWidget);expect(find.text('Scan QR code'),findsOneWidget);expect(t.takeException(),isNull);
 });
 if(needsReminderIntro) {
   testWidgets('notification permission is requested only by Accept, never by navigating slides',(t)async{
   var requests=0,finished=false;
   TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(visionChannel,(call)async{if(call.method=='reminderPermission'){requests++;return true;}return null;});
   addTearDown(()=>TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(visionChannel,null));
   await t.pumpWidget(MaterialApp(theme:v3Theme(),home:Scaffold(body:FeatureOnboarding(onDone:()=>finished=true))));await t.pumpAndSettle();
   await t.tap(find.text('Open my kitchen'));await t.pumpAndSettle();
   await t.tap(find.text('See how'));await t.pumpAndSettle();await t.tap(find.text('See how'));await t.pumpAndSettle();
   expect(requests,0);expect(find.text('Allow notifications'),findsOneWidget);expect(find.text('Skip'),findsOneWidget);
   await t.tap(find.text('Allow notifications'));await t.pumpAndSettle();expect(requests,1);expect(finished,true);expect((await SharedPreferences.getInstance()).getBool('v3.$appId.reminders'),true);
 });
 }
 testWidgets('support retains a 24-hour cooldown across reopening without losing a draft',(t)async{
   SharedPreferences.setMockInitialValues({'feedback.lastSent':DateTime.now().millisecondsSinceEpoch,'feedback.draft':'My saved feedback draft.'});var sends=0;
   await t.pumpWidget(MaterialApp(theme:v3Theme(),home:Scaffold(body:ListView(children:[FeedbackForm(send:({required category,required message})async{sends++;return FeedbackOutcome.sent;})]))));await t.pumpAndSettle();
   expect(t.widget<FilledButton>(find.byType(FilledButton)).onPressed,isNull);expect(find.textContaining('again tomorrow'),findsOneWidget);expect(find.text('My saved feedback draft.'),findsOneWidget);expect(sends,0);
 });
}
const visionChannel=MethodChannel('com.boxill/vision');
