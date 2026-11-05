// Reapply the tracked OAuth bridge to Godot's generated/ignored Android template.
const fs=require('node:fs'),path=require('node:path');
const root=path.resolve(__dirname,'..'),android=path.join(root,'android/build/src/main');
if(!fs.existsSync(android))throw Error('Install the Godot Android build template before preparing OAuth');
const java=path.join(android,'java/com/godot/game');
fs.copyFileSync(path.join(root,'platform/android/auth/LakeboundAuthBridge.java'),path.join(java,'LakeboundAuthBridge.java'));
const activity=path.join(java,'GodotApp.java');let code=fs.readFileSync(activity,'utf8');
if(!code.includes('LakeboundAuthBridge.capture(getIntent())')){
 const marker='super.onCreate(savedInstanceState);';if(!code.includes(marker))throw Error('Unsupported GodotApp template');
 code=code.replace(marker,marker+'\n\t\tLakeboundAuthBridge.capture(getIntent());');
}
if(!code.includes('LakeboundAuthBridge.capture(intent)')){
 const marker='\t@Override\n\tpublic void onResume()';
 code=code.replaceAll('\r\n','\n');if(!code.includes(marker))throw Error('Unsupported GodotApp lifecycle');
 code=code.replace(marker,'\t@Override\n\tprotected void onNewIntent(android.content.Intent intent) {\n\t\tsuper.onNewIntent(intent);\n\t\tsetIntent(intent);\n\t\tLakeboundAuthBridge.capture(intent);\n\t}\n\n'+marker);
}
fs.writeFileSync(activity,code);
const manifest=path.join(android,'AndroidManifest.xml');let xml=fs.readFileSync(manifest,'utf8');
if(!xml.includes('com.zylaah.lakebound')){
 const re=/(<activity\s+android:name="\.GodotApp"[\s\S]*?)(\s*\/>)/;
 if(!re.test(xml))throw Error('Unsupported Godot activity manifest');
 xml=xml.replace(re,(_,attrs)=>attrs.replace('android:exported="false"','android:exported="true"')+' >\n            <intent-filter>\n                <action android:name="android.intent.action.VIEW" />\n                <category android:name="android.intent.category.DEFAULT" />\n                <category android:name="android.intent.category.BROWSABLE" />\n                <data android:scheme="com.zylaah.lakebound" android:host="auth" android:path="/callback" />\n            </intent-filter>\n        </activity>');
}
xml=xml.replace(/(<activity\s+android:name="\.GodotApp"[^>]*android:launchMode=")[^"]+"/, '$1singleTask"');
fs.writeFileSync(manifest,xml);
// Godot regenerates the release overlay immediately before invoking Gradle.
// mergeOnlyAttributes drops the main manifest's OAuth intent-filter children.
// Patch that generated overlay when Gradle starts its manifest merge, after
// Godot has written it, while preserving the launcher's existing merge policy.
const gradle=path.join(root,'android/build/build.gradle');
let gradleCode=fs.readFileSync(gradle,'utf8');
if(!gradleCode.includes('// Lakebound OAuth manifest merge')){
 gradleCode+=`\n// Lakebound OAuth manifest merge\ntasks.configureEach { task ->\n    if (task.name.startsWith('process') && task.name.endsWith('MainManifest')) {\n        task.doFirst {\n            ['release', 'debug'].each { variant ->\n                def overlay = file("src/" + variant + "/AndroidManifest.xml")\n                if (overlay.exists()) {\n                    def text = overlay.getText('UTF-8')\n                    text = text.replaceAll(/(<activity\\s+android:name="\\.GodotApp"[^>]*tools:node=")mergeOnlyAttributes"/, '$1merge"')\n                    overlay.write(text, 'UTF-8')\n                }\n            }\n        }\n    }\n}\n`;
 fs.writeFileSync(gradle,gradleCode);
}
console.log('Android Google OAuth callback bridge prepared.');
