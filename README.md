# Automatización del Preprocesamiento de fMRI

Este script está diseñado para automatizar el **preprocesamiento de imágenes de resonancia magnética funcional (fMRI)** utilizando herramientas como `robustfov`, `bet` y `FEAT`. Proporciona opciones para seleccionar archivos tanto mediante una interfaz gráfica como por terminal.

## Requisitos

Para que el script funcione correctamente, debes cumplir con los siguientes requisitos:

- **Sistema Operativo**:
  - **Linux** o cualquier sistema operativo tipo Unix.
  - **Windows** con **WSL** (Windows Subsystem for Linux) o utilizando una máquina virtual.
  - **macOS**, pero **sin interfaz gráfica** por el momento (falta adecuarlo para esta plataforma).

- **Herramientas necesarias**:
  - **FSL** (FMRIB Software Library): Incluye las herramientas `robustfov`, `bet`, y `FEAT` para el preprocesamiento.
  - **Zenity**: Para la selección de archivos mediante un cuadro de diálogo gráfico. *(Instalación opcional)*.
  - **Bash**: El script está escrito en bash y no requiere el uso de otros lenguajes como Python.

## Funcionalidades

### 1. Preprocesamiento de Imágenes fMRI

El script permite realizar el preprocesamiento completo de imágenes fMRI, con las siguientes fases:

1. **Selección del Archivo**: Puedes elegir entre:
   - **Interfaz Gráfica**: Si está disponible Zenity (no compatible aún con macOS).
   - **Terminal**: Si no se instala Zenity o prefieres este método, puedes ingresar la ruta del archivo manualmente.
  
2. **Recorte de Cuello** (`robustfov`): 
   - El script realiza un recorte de cuello en la imagen seleccionada utilizando la herramienta `robustfov`.

3. **Extracción del Cerebro** (`bet`)[_En proceso_]: 
   - Realiza la extracción de la estructura cerebral en las imágenes para aislar el cerebro de otras estructuras.

4. **Preprocesamiento Completo** (`FEAT`)[_En proceso_]: 
   - La automatización incluye la ejecución de un flujo de trabajo completo de preprocesamiento mediante `FEAT`, ideal para análisis avanzados de fMRI.

5. **Mensajes Informativos**: Al final de cada fase, el script informará de la finalización del proceso y la ubicación del archivo guardado.

### 2. Instalación Automática de Zenity (opcional)

Si Zenity no está instalado, el script detecta la distribución de Linux e intenta instalarlo automáticamente para facilitar la selección gráfica de archivos. Si la instalación falla o prefieres no usarla, puedes proceder con la selección de archivos vía terminal.

### Próximas Funcionalidades y Correcciones

- [ ] **Soporte para macOS con Interfaz Gráfica**: Añadir una solución gráfica para macOS ya que Zenity no está disponible en esta plataforma.
- [ ] **Procesamiento en Lote**: Implementar la posibilidad de procesar múltiples imágenes en una única ejecución del script.
- [ ] **Omición de función**: Si ya existe el archivo `_cropped`, evita gastar tiempo en repetir el proceso.
- [ ] **Estandar BIDS**: Organizar los resultados en estandar BIDS (derivatives)

## Uso

1. **Clonar el repositorio**:
   ```bash
   git clone https://github.com/diegouhh/fmri-workflow-automation.git
   cd fmri-workflow-automation
2. **Dar permisos de ejecución**:
    ```bash
    chmod +x Prototipo1.sh
3. **Ejecutar el script**:
    ```bash
    ./Prototipo1.sh