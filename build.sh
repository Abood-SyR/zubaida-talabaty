#!/bin/bash
FLUTTER_SDK_PATH="$HOME/flutter"
if [ ! -d "$FLUTTER_SDK_PATH" ]; then
  git clone --branch stable https://github.com/flutter/flutter.git $FLUTTER_SDK_PATH
fi
export PATH="$FLUTTER_SDK_PATH/bin:$PATH"
flutter config --enable-web
flutter pub get
flutter build web --release --dart-define=FLUTTER_WEB_RENDERER=html