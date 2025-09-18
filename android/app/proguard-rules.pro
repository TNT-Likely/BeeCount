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

# Preserve line numbers for debugging crashes
-keepattributes SourceFile,LineNumberTable

# Keep custom application classes
-keep public class * extends android.app.Application
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service