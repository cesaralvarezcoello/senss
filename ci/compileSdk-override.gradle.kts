// Añadido por la CI al android/build.gradle.kts raíz generado.
// Fuerza compileSdk 36 en TODOS los módulos (app + plugins), porque plugins
// como file_picker se compilan por separado y flutter_plugin_android_lifecycle
// exige API 36+. Ver .github/workflows/ci.yml.
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.compileSdkVersion(36)
    }
}
