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

# Preserve line numbers for debugging crashes
-keepattributes SourceFile,LineNumberTable

# Keep custom application classes
-keep public class * extends android.app.Application
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service