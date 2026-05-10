# Libro Semillero - Metodos Metaheuristicos

Proyecto colaborativo en LaTeX para escribir el libro del semillero sobre
metodos metaheuristicos aplicados a controladores PID.

Este repositorio usa un asistente llamado `sync.cmd` para que el equipo pueda
trabajar sin tener que aprender Git a profundidad. El asistente se encarga de
descargar la version mas reciente, guardar tus cambios y enviarlos a GitHub.

## Glosario rapido

En el asistente usaremos lenguaje simple. Entre parentesis aparece el nombre
tecnico de Git/GitHub por si alguien necesita reconocerlo despues.

| Lenguaje simple | Nombre tecnico | Que significa |
| --- | --- | --- |
| Carpeta del proyecto | Repositorio local | La carpeta del libro en tu computadora. |
| Nube del equipo | Repositorio remoto | El proyecto guardado en GitHub. |
| Descargar ultima version | Pull | Traer a tu computadora lo ultimo que subio el equipo. |
| Guardar un avance | Commit | Crear un punto de guardado con tus cambios. |
| Enviar cambios | Push | Subir tus avances a GitHub. |
| Solicitar revision | Pull Request | Pedir que un mantenedor acepte tus cambios. |
| Copia personal | Fork | Copia del repositorio en tu cuenta de GitHub. |
| Linea de trabajo | Rama | Version paralela del proyecto. Normalmente usamos `main`. |
| Choque de cambios | Conflicto | Dos personas editaron la misma parte y Git necesita ayuda. |

## Inicio rapido

### Windows

1. Descarga o copia el archivo `sync.cmd`.
2. Haz doble clic sobre `sync.cmd`.
3. Si Git no esta instalado, el asistente intentara instalarlo.
4. Inicia sesion en GitHub cuando el asistente lo pida.
5. Pega el link del proyecto cuando se te pida.
6. Elige la carpeta donde quieres trabajar.

Despues del primer inicio, puedes volver a ejecutar el mismo archivo. El
asistente recordara la carpeta del proyecto.

### Linux

Abre una terminal en la carpeta donde tengas `sync.cmd` y ejecuta:

```bash
bash sync.cmd
```

Si Git no esta instalado, el asistente mostrara una sugerencia segun tu sistema.

## Flujo recomendado de trabajo

Antes de editar:

1. Ejecuta `sync.cmd`.
2. Elige `1) Descargar la ultima version del equipo`.
3. Abre el libro en TeXstudio o en tu editor preferido.

Despues de editar:

1. Guarda tus archivos en el editor.
2. Compila el documento para revisar que no haya errores.
3. Ejecuta `sync.cmd`.
4. Elige `2) Guardar y enviar mis cambios`.
5. Describe que parte modificaste y que hiciste.

La opcion `2` hace tres cosas:

1. Descarga primero lo ultimo del equipo (`pull`).
2. Guarda tu avance con una descripcion (`commit`).
3. Lo envia a GitHub (`push`).

## Menu del asistente

```text
1) Descargar la ultima version del equipo (pull)
2) Guardar y enviar mis cambios (pull + commit + push)
3) Ver que archivos cambiaron (status)
4) Configurar mi nombre/correo para los guardados (git config)
5) Configurar el enlace del proyecto en GitHub (remote)
6) Cambiar linea de trabajo - avanzado (branch)
0) Salir
```

Para el trabajo normal casi siempre usaras solo las opciones `1` y `2`.

## Uso con TeXstudio o cualquier editor

El archivo principal del libro es:

```text
libro_metaheuristicas_pid_overleaf/main.tex
```

En TeXstudio:

1. Abre `main.tex`.
2. Configura el compilador como `XeLaTeX`.
3. Compila desde `main.tex`, no desde un capitulo suelto.
4. Edita el capitulo o seccion que te corresponde.

Si usas VS Code, Texmaker, Overleaf u otro editor, aplica la misma regla: el
documento principal es `main.tex`.

## Estructura del proyecto

```text
libro_metaheuristicas_pid_overleaf/
  main.tex                         Archivo principal
  config/                          Preambulo, estilos y datos generales
  frontmatter/                     Portada, resumen, prologo, introduccion
  capitulos/                       Capitulos principales
  figuras/                         Imagenes y graficos
  tablas/                          Tablas
  referencias/referencias.bib      Bibliografia
  backmatter/                      Referencias y autores
  anexos/                          Anexos
```

Capitulos:

```text
cap01_fundamentos_control_pid.tex
cap02_criterios_desempeno.tex
cap03_sintonizacion_clasica_pid.tex
cap04_formulacion_problema_optimizacion.tex
cap05_fundamentos_metaheuristicos.tex
cap06_pso.tex
cap07_gwo.tex
cap08_eagle_strategy.tex
cap09_artificial_bee_colony.tex
cap10_metodologia_comparativa.tex
cap11_casos_estudio.tex
cap12_resultados_discusion.tex
cap13_conclusiones_trabajos_futuros.tex
```

Nota: si el nombre de un capitulo cambia, revisa siempre lo que aparece en la
carpeta `capitulos/` y en `main.tex`.

## Como guardar y enviar cambios

Ejecuta `sync.cmd` y elige:

```text
2) Guardar y enviar mis cambios (pull + commit + push)
```

El asistente preguntara:

```text
Que seccion o capitulo modificaste?
Describe brevemente tu aporte o cambios:
```

Ejemplos:

```text
Seccion: Capitulo 6 - PSO
Descripcion: Mejore la explicacion de la actualizacion de velocidad
```

```text
Seccion: Referencias
Descripcion: Agregue fuentes sobre sintonia PID con metaheuristicas
```

Con esa informacion el asistente crea un punto de guardado (`commit`) con un
mensaje claro para el historial.

## Si no tienes permiso para enviar directo

Puede ocurrir que GitHub diga que no tienes permiso de escritura (`403`). Eso
significa que tu cuenta puede ver el proyecto, pero no puede escribir
directamente en la version principal.

En ese caso:

1. Tus cambios no se pierden.
2. El asistente los guarda en tu computadora (`commit local`).
3. El asistente intenta subirlos a tu copia personal (`fork`).
4. Luego crea o muestra un enlace para solicitar revision (`Pull Request`).

Un mantenedor del proyecto revisara esa solicitud y la aceptara para que tus
cambios entren a `main`.

## Si aparece un choque de cambios

Un choque de cambios (`conflicto`) ocurre cuando dos personas editaron la misma
parte de un archivo.

Si pasa:

1. El asistente se detendra.
2. Te mostrara que archivos tienen problema.
3. Debes abrir esos archivos y buscar marcas como:

```text
<<<<<<<
=======
>>>>>>>
```

4. Decide que texto debe quedar.
5. Guarda el archivo.
6. Ejecuta otra vez `sync.cmd`.

Si no estas seguro, no borres contenido. Pide ayuda al equipo.

Tambien puedes ver marcas como estas:

```text
<<<<<<< Updated upstream
Texto que vino desde GitHub
=======
Texto que tenias en tu computadora
>>>>>>> Stashed changes
```

Eso no lo escribe el asistente. Lo escribe Git automaticamente cuando intento
descargar la version nueva y volver a colocar encima tus cambios locales. En ese
caso:

- `Updated upstream` es lo que venia de GitHub.
- `Stashed changes` es lo que tenias guardado temporalmente en tu computadora.
- La linea `=======` separa ambas versiones.

Debes dejar solo el texto final correcto y borrar las marcas `<<<<<<<`,
`=======` y `>>>>>>>`.

## Archivos que se suben y archivos que no

El repositorio ignora archivos temporales generados al compilar LaTeX:

```text
*.aux
*.log
*.toc
*.out
*.synctex.gz
*.pdf
```

Esto evita subir basura tecnica o PDFs generados automaticamente.

Excepcion:

```text
pso final borrador.pdf
```

Ese archivo si se sube porque es una referencia de trabajo para el libro.

## Reglas simples del equipo

- Antes de editar, descarga la ultima version del equipo (`pull`).
- Edita solo tu seccion o lo que se haya acordado.
- Antes de enviar cambios, compila el libro.
- No borres contenido de otra persona sin avisar.
- No subas archivos temporales de LaTeX.
- Escribe descripciones claras cuando el asistente pregunte que hiciste.
- Si aparece un error, lee el mensaje antes de cerrar la ventana.
- Si aparece un conflicto, pide ayuda si no estas seguro.

## Comandos utiles para quien quiera revisar manualmente

Ver que archivos cambiaron:

```bash
git status
```

Ver ultimos guardados:

```bash
git log --oneline -5
```

Ejecutar el asistente en Linux:

```bash
bash sync.cmd
```

En Windows, normalmente basta con doble clic sobre `sync.cmd`.
