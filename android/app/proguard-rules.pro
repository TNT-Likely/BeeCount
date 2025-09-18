# Keep notification receiver classes
-keep class com.example.beecount.NotificationReceiver { *; }
-keep class com.example.beecount.NotificationClickReceiver { *; }
-keep class com.example.beecount.MainActivity { *; }

# Keep all BroadcastReceiver subclasses
-keep public class * extends android.content.BroadcastReceiver

# Keep notification-related methods
-keepclassmembers class com.example.beecount.** {
    public void onReceive(android.content.Context, android.content.Intent);
}

# Keep Flutter notification plugin classes
-keep class io.flutter.** { *; }
-keep class com.dexterous.** { *; }

# Keep flutter_local_notifications plugin classes
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class com.dexterous.flutterlocalnotifications.FlutterLocalNotificationsPlugin { *; }

# Keep notification plugin method signatures and generics
-keepclassmembers class com.dexterous.flutterlocalnotifications.** {
    public *;
}

# Preserve generic signatures for plugin methods
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Keep timezone data for notifications
-keep class net.danlew.android.joda.** { *; }

# Keep notification-related enum classes
-keep class * extends java.lang.Enum { *; }

# Keep notification channel related classes
-keep class android.app.NotificationChannel { *; }
-keep class android.app.NotificationManager { *; }
-keep class androidx.core.app.NotificationCompat** { *; }

# Keep alarm manager classes
-keep class android.app.AlarmManager { *; }
-keep class android.app.PendingIntent { *; }

# Keep method channel related classes
-keep class io.flutter.plugin.common.** { *; }

# Keep dialog and UI related classes (防止APK安装器闪退)
-keep class android.app.AlertDialog { *; }
-keep class android.app.Dialog { *; }
-keep class android.content.DialogInterface { *; }
-keep class androidx.appcompat.app.AlertDialog { *; }

# Keep file provider classes (APK安装相关)
-keep class androidx.core.content.FileProvider { *; }
-keep class android.support.v4.content.FileProvider { *; }

# Keep package installer classes
-keep class android.content.pm.PackageInstaller { *; }
-keep class android.content.pm.PackageManager { *; }

# Keep Intent related classes for APK installation
-keep class android.content.Intent { *; }
-keep class android.net.Uri { *; }

# Keep OpenFilex plugin classes (用于APK安装)
-keep class com.crazecoder.openfile.** { *; }

# Keep all FileProvider related classes and methods (防止混淆影响APK安装)
-keep class androidx.core.content.FileProvider { *; }
-keep class androidx.core.content.FileProvider$** { *; }
-keepclassmembers class androidx.core.content.FileProvider {
    public *;
    private *;
}

# Keep XML parser related classes (修复IncompatibleClassChangeError)
-keep class android.content.res.XmlBlock { *; }
-keep class android.content.res.XmlBlock$Parser { *; }
-keep interface android.content.res.XmlResourceParser { *; }
-keep interface org.xmlpull.v1.XmlPullParser { *; }

# Keep XML parsing implementation classes
-keep class org.xmlpull.v1.** { *; }
-dontwarn org.xmlpull.v1.**

# Keep method signatures for file provider paths
-keepattributes *Annotation*
-keep class * extends androidx.core.content.FileProvider

# Prevent obfuscation of authority strings
-keepclassmembers class ** {
    @androidx.core.content.FileProvider$* <fields>;
}

# 保护Android系统XML接口不被混淆 (关键修复)
-keep interface android.content.res.** { *; }
-keep class android.content.res.** { *; }

# Preserve line numbers for debugging crashes
-keepattributes SourceFile,LineNumberTable

# Keep custom application classes
-keep public class * extends android.app.Application
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service

# Ignore missing Google Play Core classes (not needed for direct APK distribution)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# Ignore Flutter Play Store related classes
-dontwarn io.flutter.app.FlutterPlayStoreSplitApplication
-dontwarn io.flutter.embedding.engine.deferredcomponents.PlayStoreDeferredComponentManager**