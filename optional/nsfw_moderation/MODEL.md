# Modelo de moderación NSFW (on-device)

Coloca aquí un modelo TensorFlow Lite de clasificación **seguro / no-seguro**
con el nombre:

```
assets/models/nsfw.tflite
```

`NsfwModerationService` lo carga desde este directorio y clasifica cada foto
**en el dispositivo** antes de guardarla. Ningún pixel sale del teléfono.

## Modelos compatibles

El servicio se adapta a la forma de salida del modelo:

- **Salida de 1 valor (sigmoide):** se interpreta como probabilidad de contenido
  no-seguro. Ej. modelos tipo Yahoo `open_nsfw` convertidos a 1 salida.
- **Salida de 2 clases** `[seguro, no_seguro]`: índice no-seguro = `1`.
- **Salida de 5 clases** (estilo GantMan `nsfw_model`)
  `[drawings, hentai, neutral, porn, sexy]`: índices no-seguros = `1, 3, 4`.

Configura los índices, el umbral y la normalización al construir
`NsfwModerationService(...)` si tu modelo difiere del valor por defecto
(5 clases, entrada 224×224 normalizada a `[0, 1]`, umbral `0.7`).

> Sin este archivo la app compila y funciona, pero la moderación **aprueba
> todo** y escribe un aviso en consola. Colócalo antes de publicar.
