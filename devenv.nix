{ pkgs, ... }:

{
  packages = with pkgs; [
    git
    curl
    unzip
    zip
    which
    jdk17
    pkg-config
    ninja
    cmake
  ];

  android = {
    enable = true;
    flutter = {
      enable = true;
      package = pkgs.flutter329;
    };

    platforms.version = [ "31" "34" "35" "36" ];
    buildTools.version = [ "33.0.1" "34.0.0" ];

    cmdLineTools.version = "11.0";

    ndk = {
      enable = true;
      version = [ "25.1.8937393" ];
    };

    emulator.enable = false;
    systemImages.enable = false;
  };

  enterShell = ''
    export JAVA_HOME="${pkgs.jdk17}"
    export PATH="$JAVA_HOME/bin:$PATH"
    export NIX_NINJA_BIN="${pkgs.ninja}/bin/ninja"
    export CMAKE_MAKE_PROGRAM="${pkgs.ninja}/bin/ninja"
    export GRADLE_OPTS="-Dorg.gradle.project.android.cmake.path=${pkgs.cmake} -Dorg.gradle.project.android.ninja.path=${pkgs.ninja}/bin/ninja"

    # Ensure lib/system/environment.dart exists
    if [ ! -f "lib/system/environment.dart" ]; then
      mkdir -p lib/system
      cat << 'EOF' > lib/system/environment.dart
class LunaEnvironment {
  static const String flavor = 'stable';
}
EOF
    fi

    # Point AGP to nixpkgs native cmake via local.properties
    mkdir -p android
    touch android/local.properties
    sed -i '/cmake.dir=/d' android/local.properties
    echo "cmake.dir=${pkgs.cmake}" >> android/local.properties

    echo "Flutter Android development environment"
    flutter --version
    java -version
  '';

  scripts.doctor.exec = ''
    flutter doctor -v
  '';

  scripts.codegen.exec = ''
    flutter pub get
    dart run build_runner build --delete-conflicting-outputs
  '';

  scripts.apk.exec = ''
    flutter pub get
    flutter build apk --debug --target-platform android-arm64
  '';

  scripts.run-android.exec = ''
    flutter run
  '';
}
