#!/bin/bash

# مسار لتخزين Flutter SDK
FLUTTER_SDK_PATH="$HOME/flutter"

# التحقق من وجود Flutter، وإذا لم يكن موجودًا، قم بتثبيته
if [ ! -d "$FLUTTER_SDK_PATH" ]; then
  git clone --branch stable https://github.com/flutter/flutter.git $FLUTTER_SDK_PATH
fi

# إضافة Flutter إلى PATH
export PATH="$FLUTTER_SDK_PATH/bin:$PATH"

# تمكين دعم الويب (اختياري لكن مفيد)
flutter config --enable-web

# جلب الاعتماديات
flutter pub get

# بناء تطبيق الويب
flutter build web --release