# flutter_gemma / MediaPipe (requerido por el plugin, ver su README)
-keep class com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**
-keep class com.google.ai.edge.localagents.** { *; }
-dontwarn com.google.ai.edge.localagents.**

# google_mlkit_text_recognition — solo usamos el reconocedor de script latino
# (TextRecognitionScript.latin); los reconocedores de otros idiomas son
# clases opcionales que ni siquiera están en el classpath, R8 solo necesita
# saber que no son un error.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
