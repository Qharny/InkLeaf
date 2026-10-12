# Inkleaf only bundles the Latin text recognizer. ML Kit's plugin references
# the optional Chinese, Devanagari, Japanese and Korean ones too, which would
# otherwise fail the minified release build.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
