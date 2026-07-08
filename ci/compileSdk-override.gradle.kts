// Añadido por la CI al android/build.gradle.kts raíz generado.
// Fuerza compileSdk 36 en los módulos de plugins (file_picker, etc.), que se
// compilan aparte y que flutter_plugin_android_lifecycle exige en API 36+.
// El módulo :app se fija por separado (sed) y aquí se omite: la plantilla lo
// evalúa antes por `evaluationDependsOn(":app")`, y afterEvaluate sobre un
// proyecto ya evaluado lanzaría una excepción.
subprojects {
    if (!state.executed) {
        afterEvaluate {
            extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
                ?.compileSdkVersion(36)
        }
    }
}
