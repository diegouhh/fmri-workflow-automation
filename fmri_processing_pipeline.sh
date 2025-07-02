#!/bin/bash

# ==================================================================================
# Título: Pipeline de Procesamiento task-fMRI
# Autores: Juan Diego Ortega Álvarez, Juan José Sierra Peña. - Bioingeniería.
# Descripción:
# Este script automatiza el procesamiento de imágenes de resonancia magnética 
# funcional en tarea (task-fMRI) utilizando herramientas especializadas de FSL 
# como `robustfov`, `bet` y `FEAT`. El flujo de trabajo incluye el recorte 
# de la región del cuello, la extracción del cerebro y la configuración 
# automatizada de los pasos para el preprocesamiento de datos de fMRI.
#
# El script ofrece opciones para seleccionar archivos tanto de forma gráfica 
# como desde la terminal, asegurando la correcta ejecución de cada proceso y 
# confirmando la instalación de herramientas como `Zenity` para la selección 
# gráfica de archivos, si es necesario.
#
# Guía de Uso:
# 1. Clona el repositorio y accede a la carpeta:
#    Antes de clonar el repositorio, navega a la carpeta donde deseas almacenar el repositorio clonado.
#    Puedes hacerlo con el comando `cd` para cambiar a la ubicación deseada. Por ejemplo:
#    cd /ruta/a/la/carpeta/destino
#
#    Luego, clona el repositorio desde GitHub a tu máquina local usando el siguiente 
#    comando. Esto descargará todos los archivos necesarios para ejecutar el script:
#    git clone https://github.com/diegouhh/fmri-workflow-automation.git
#
#    Una vez clonado, navega a la carpeta del repositorio clonado para acceder al script:
#    cd fmri-workflow-automation
#
# 2. Otorga permisos de ejecución al script:
#    Antes de ejecutar el script, es necesario otorgarle permisos de ejecución. 
#    Usa el siguiente comando para asegurarte de que el archivo `fmri_processing_pipeline.sh` 
#    sea ejecutable:
#    chmod +x fmri_processing_pipeline.sh
#
# 3. Ejecuta el script:
#    Una vez que el script tenga permisos de ejecución, ya puedes correrlo. 
#    Para ello, puedes usar alguna de las siguientes opciones:
#
#    Opción 1: Ejecución directa con ./ (modo estándar):
#    Este es el método más común y sencillo. Simplemente ejecuta el script con el siguiente comando:
#    ./fmri_processing_pipeline.sh
#
#    Opción 2: Ejecución usando `bash` explícitamente:
#    Si prefieres usar `bash` para ejecutar el script directamente, puedes hacerlo con el siguiente comando:
#    bash fmri_processing_pipeline.sh
#
# 4. Selección de archivos:
#    Cuando ejecutes el script, se te solicitará seleccionar los archivos de entrada, 
#    ya sea mediante una ventana gráfica (si tienes Zenity instalado) o a través de 
#    la terminal. El script guiará cada paso del proceso.
#
# 5. Confirmación y ejecución:
#    El script realizará las tareas de procesamiento, como el recorte de la región 
#    del cuello, la extracción del cerebro y la configuración del análisis de fMRI.
#    Asegúrate de que las herramientas de FSL (robustfov, bet y FEAT) estén 
#    correctamente instaladas antes de ejecutar el script.
#
# 6. Visualización de resultados:
#    Tras la ejecución, el script generará los archivos de salida que podrás 
#    revisar y usar para los siguientes pasos en tu análisis de fMRI.
#
# Requisitos:
# - Linux o sistema operativo basado en Unix con Bash.
# - FSL (incluye las herramientas robustfov, bet y FEAT).
# - Opcional: Zenity para la selección gráfica de archivos.
#
# Próximas Funcionalidades:
# - Procesamiento en lote de múltiples imágenes en una sola ejecución (FEAT).
# - Optimización para detectar y omitir el procesamiento si ya existen archivos _crop.
# - Compatibilidad con el estándar BIDS para organizar los resultados en carpetas de derivados.
#
# ==================================================================================

source "$(dirname "$0")/funciones.sh" # Importa funciones desde el archivo funciones.sh. $0 es la ruta del script actual.

# Variables de color (mostrados en la terminal)
COLOR_ERROR="\e[38;5;203m"    # Rojo claro
COLOR_ADVERTENCIA="\e[38;5;190m"  # Amarillo claro
COLOR_EXITO="\e[38;5;154m"  # Verde claro
COLOR_MODULO="\e[38;5;99m"    # Divide comandos principales
COLOR_NORMAL="\e[0m"          # Color normal
procesos_paralelos="8"

# Mensaje de introducción
echo -e "${COLOR_MODULO}=============================================="
echo -e "${COLOR_MODULO}   Automatización del Preprocesamiento de"
echo -e "${COLOR_MODULO}  Imágenes de Resonancia Magnética Funcional"
echo -e "${COLOR_MODULO}     (Utilizando robustfov, bet y FEAT)"
echo -e "${COLOR_MODULO}==============================================${COLOR_NORMAL}\n"

while true; do
# Menú para elegir entre BIDS o archivo individual
echo -e -n $'¿Deseas procesar un archivo individual o trabajar con un directorio BIDS?\n\n- Archivo individual (i)\n- Directorio BIDS (b)\n\nElige una opción (i/b): '
read -r opcion_entrada

# ==================================================================================
# Robustfov individual
# ==================================================================================
if [[ "$opcion_entrada" == "i" || "$opcion_entrada" == I ]]; then  
    echo -e "${COLOR_MODULO}Has elegido procesar un archivo individual.${COLOR_NORMAL}"
    # Bucle para repetir el menú hasta que el usuario elija una opción válida
    while true; do
        echo -e -n $'\n¿Cómo deseas ingresar los datos? \n\n- Interfaz gráfica (g)\n- Terminal (t)\n\nElige una opción (g/t): '
        read -r metodo_entrada

        if [[ "$metodo_entrada" == "g" || "$metodo_entrada" == "G" ]]; then
            # Comprueba si Zenity está instalado, despreciando el output de ´command´
            if ! command -v zenity &> /dev/null; then
                echo -e "${COLOR_ADVERTENCIA}\nZenity no está instalado.${COLOR_NORMAL}"

                # Preguntar si se quiere instalar Zenity
                read -p "Deseas instalar Zenity? (s/n) " instalar_zenity
                if [[ "$instalar_zenity" == "s" || "$instalar_zenity" == "S" ]]; then
                        # Verificar si el usuario tiene permisos de sudo
                        if ! sudo -l &> /dev/null; then
                            echo -e "${COLOR_ERROR}No tienes permisos de sudo para instalar Zenity. Usando la entrada por terminal.${COLOR_NORMAL}"
                            solicitar_ruta_terminal_individual
                            break
                        else
                            # Detecta la distro y usa el comando de instalación correspondiente
                            if [[ -f /etc/arch-release ]]; then
                                sudo pacman -S --noconfirm zenity  # Para Archlinux
                            elif [[ -f /etc/debian_version ]]; then
                                sudo apt-get update && sudo apt-get install -y zenity  # Para Ubuntu y Debian
                            elif [[ -f /etc/fedora-release ]]; then
                                sudo dnf install -y zenity  # Para Fedora
                            elif [[ -f /etc/SuSE-release ]]; then
                                sudo zypper install -y zenity  # Para openSUSE
                            else   
                                echo -e "${COLOR_ERROR}No se pudo detectar la distribución.${COLOR_NORMAL}"
                                echo -e "Usando la entrada por terminal."
                                solicitar_ruta_terminal_individual
                                break
                            fi
                            # Comprobar si zenity se instaló exitosamente
                            if command -v zenity &> /dev/null; then
                            
                            # Si Zenity está instalado, solicitar la ruta del archivo mediante un cuadro de diálogo gráfico
                                echo -e "Selecciona un archivo .nii o .nii.gz."
                                ruta_imagen=$(zenity --file-selection --title="Selecciona un archivo .nii o .nii.gz" --filename="$HOME/" --file-filter="*.nii *.nii.gz" 2>/dev/null)

                                # Comprobar si se seleccionó un archivo
                                if [[ -z "$ruta_imagen" ]]; then
                                    echo -e "${COLOR_ERROR}No se seleccionó ningún archivo. Saliendo...${COLOR_NORMAL}"
                                    exit 1
                                fi
                            else
                                echo -e "${COLOR_ERROR}La instalación de Zenity falló. Usando la entrada por terminal.${COLOR_NORMAL}"
                                solicitar_ruta_terminal_individual
                                break
                            fi
                        fi
                fi
            else
                # Si Zenity está instalado, solicitar la ruta del archivo mediante un cuadro de diálogo gráfico
                echo -e "Selecciona un archivo .nii o .nii.gz."
                ruta_imagen=$(zenity --file-selection --title="Selecciona un archivo .nii o .nii.gz" --filename="$HOME/" --file-filter="*.nii *.nii.gz" 2>/dev/null)

                # Comprobar si se seleccionó un archivo
                if [[ -z "$ruta_imagen" ]]; then
                    echo -e "${COLOR_ERROR}No se seleccionó ningún archivo. Saliendo...${COLOR_NORMAL}"
                    exit 1
                fi
            fi
            break  # Salir del bucle si la opción fue válida

        elif [[ "$metodo_entrada" == "t" || "$metodo_entrada" == "T" ]]; then
            # Ruta directa vía terminal
            solicitar_ruta_terminal_individual
            break  # Salir del bucle si la opción fue válida

        else
            echo -e "${COLOR_ERROR}\nOpción no válida. Por favor, ingresa 'g' o 't'. ${COLOR_NORMAL}"
            # El bucle continuará, repitiendo el menú
        fi
    done

    # Definir el nombre base para el archivo recortado
    nombre_base_crop="${ruta_imagen%%.*}_crop.nii.gz"

    # Comprobar si el archivo de salida ya existe y sobreescribir
    if [ -f "$nombre_base_crop" ]; then
        echo -e "${COLOR_ADVERTENCIA}\nEl archivo ${nombre_base_crop##*/} ya existe. Será sobrescrito.\n${COLOR_NORMAL}"
    else   
        echo -e "\nEl archivo será guardado como ${nombre_base_crop##*/}.\n"
    fi

    # Mensaje de inicio del proceso
    echo -e "Recorte de cuello iniciado...\n"
    # Ejecutar robustfov para realizar la operación
    robustfov -i "$ruta_imagen" -r "$nombre_base_crop"
    # Mensaje de finalización
    echo -e "${COLOR_EXITO}Resultado guardado en la ruta ${nombre_base_crop} el día $(date)${COLOR_NORMAL}"
    break

# ==================================================================================
#Robustfov BIDS
# ==================================================================================
elif [[ "$opcion_entrada" == "b" || "$opcion_entrada" == "B" ]]; then
    echo -e "${COLOR_MODULO}Has elegido trabajar con un directorio BIDS.${COLOR_NORMAL}"
    while true; do
            echo -e -n $'\n¿Cómo deseas ingresar los datos? \n\n- Interfaz gráfica (g)\n- Terminal (t)\n\nElige una opción (g/t): '
            read -r metodo_entrada

            if [[ "$metodo_entrada" == "g" || "$metodo_entrada" == "G" ]]; then
            # Comprueba si Zenity está instalado, despreciando el output de ´command´
            if ! command -v zenity &> /dev/null; then
                echo -e "${COLOR_ADVERTENCIA}\nZenity no está instalado.${COLOR_NORMAL}"

                # Preguntar si se quiere instalar Zenity
                read -p "Deseas instalar Zenity? (s/n) " instalar_zenity
                if [[ "$instalar_zenity" == "s" || "$instalar_zenity" == "S" ]]; then
                        # Verificar si el usuario tiene permisos de sudo
                        if ! sudo -l &> /dev/null; then
                            echo -e "${COLOR_ERROR}No tienes permisos de sudo para instalar Zenity. Usando la entrada por terminal.${COLOR_NORMAL}"
                            solicitar_ruta_terminal_bids
                            break
                        else
                            # Detecta la distro y usa el comando de instalación correspondiente
                            if [[ -f /etc/arch-release ]]; then
                                sudo pacman -S --noconfirm zenity  # Para Archlinux
                            elif [[ -f /etc/debian_version ]]; then
                                sudo apt-get update && sudo apt-get install -y zenity  # Para Ubuntu y Debian
                            elif [[ -f /etc/fedora-release ]]; then
                                sudo dnf install -y zenity  # Para Fedora
                            elif [[ -f /etc/SuSE-release ]]; then
                                sudo zypper install -y zenity  # Para openSUSE
                            else   
                                echo -e "${COLOR_ERROR}No se pudo detectar la distribución.${COLOR_NORMAL}"
                                echo -e "Usando la entrada por terminal."
                                solicitar_ruta_terminal_bids
                                break
                            fi
                            # Comprobar si zenity se instaló exitosamente
                            if command -v zenity &> /dev/null; then
                            
                            # Si Zenity está instalado, solicitar la ruta del archivo mediante un cuadro de diálogo gráfico
                                echo -e "\nSelecciona un directorio en estándar BIDS."
                                ruta_directorio_bids=$(zenity --file-selection --directory --title="Selecciona un directorio en estándar BIDS" --filename="$HOME/" 2>/dev/null)

                                # Comprobar si se seleccionó un archivo
                                if [[ -z "$ruta_directorio_bids" ]]; then
                                    echo -e "${COLOR_ERROR}No se seleccionó ningún directorio. Saliendo...${COLOR_NORMAL}"
                                    exit 1
                                fi
                            else
                                echo -e "${COLOR_ERROR}La instalación de Zenity falló. Usando la entrada por terminal.${COLOR_NORMAL}"
                                solicitar_ruta_terminal_bids
                                break
                            fi
                        fi
                fi
            else
                # Si Zenity está instalado, solicitar la ruta del archivo mediante un cuadro de diálogo gráfico
                echo -e "\nSelecciona un directorio en estándar BIDS."

                # Detectar si se está en WSL
                if grep -qi microsoft /proc/version; then
                    # Configuración para WSL: Ruta de usuario en Windows
                    ruta_inicial="/mnt/c/Users/$USER"
                else
                    # Configuración para Linux: Ruta de usuario de Linux
                    ruta_inicial="$HOME"
                fi
                ruta_directorio_bids=$(zenity --file-selection --directory --title="Selecciona un directorio en estándar BIDS" --filename="$ruta_inicial/" 2>/dev/null)

                # Comprobar si se seleccionó un directorio
                if [[ -z "$ruta_directorio_bids" ]]; then
                    echo -e "${COLOR_ERROR}No se seleccionó ningún directorio. Saliendo...${COLOR_NORMAL}"
                    exit 1
                fi
            fi
            break  # Salir del bucle si la opción fue válida (se lleva el nombre del directorio)

        elif [[ "$metodo_entrada" == "t" || "$metodo_entrada" == "T" ]]; then
            # Ruta directa vía terminal
            solicitar_ruta_terminal_bids
            break  # Salir del bucle si la opción fue válida

        else
            echo -e "${COLOR_ERROR}\nOpción no válida. Por favor, ingresa 'g' o 't'. ${COLOR_NORMAL}"
            # El bucle continuará, repitiendo el menú
        fi
    done

    procesar_archivo_bids
    break
else
    echo -e "${COLOR_ERROR}\nOpción no válida. Por favor, ingresa 'i' o 'b'. ${COLOR_NORMAL}"

fi
done

# Anuncio de inicio del BET
echo -e "${COLOR_MODULO}\nIniciando BET (Brain Extraction Tool).${COLOR_NORMAL}"

# Verifica si nombre_base_crop está definido y no vacío (si no está vacío indica que se siguió la ruta individual.)

# ==================================================================================
# BET individual
# ==================================================================================
if [ ! -z "$nombre_base_crop" ]; then
    # Define la ruta de salida para el archivo de salida del BET, eliminando la extensión y _crop si existe
    nombre_salida_bet="$(echo "${nombre_base_crop%%.*}" | sed 's/_crop$//')_brain.nii.gz"
    echo "Procesando BET en ruta individual para: $nombre_base_crop"
    bet "$nombre_base_crop" "$nombre_salida_bet" -f 0.5
    echo -e "${COLOR_EXITO}Proceso BET completado para: $nombre_base_crop.${COLOR_NORMAL}"

else 
# ==================================================================================
# BET BIDS
# ==================================================================================
    logs_dir="$ruta_directorio_bids/derivatives/logs"
    mkdir -p "$logs_dir"
    lista_tmp="$logs_dir/lista_imagenes_a_procesar_bet.txt"
    
    find "$ruta_directorio_bids" -type f -path "*/sub-*/anat/*_crop.nii*" > "$lista_tmp"
    sed -i -E 's/\.(nii|nii\.gz)$//' "$lista_tmp"

    # Elimina salidas existentes
    while read line; do
        salida_base="$(echo "$line" | sed 's/_crop$//')_brain.nii.gz"
        [ -f "$salida_base" ] && rm "$salida_base"
    done < "$lista_tmp"

    echo "BET en curso..."

    # Ejecuta el BET sin el "_crop" en la salida
    cat "$lista_tmp" | xargs -P "${procesos_paralelos}" -I {} bash -c '
        entrada="{}"
        salida="$(echo "$entrada" | sed "s/_crop$//")_brain.nii.gz"
        bet "$entrada" "$salida"
    '

    echo -e "${COLOR_EXITO}Extracción de cerebro terminada para todos los archivos.${COLOR_NORMAL}"
fi


# ==================================================================================
# Confirmación de conversión con cuenta regresiva
# ==================================================================================
echo -e "\n" # Salto de línea para mejor estructura de la salida terminal 
echo -e "Presiona cualquier tecla para confirmar la previsualización de los resultados BET\n"
echo "En esta previsualización, podrás verificar el recorte y ajustar el umbral si es necesario."

# Contador regresivo para mostrar en la terminal
for ((i=60; i>-1; i--)); do
    echo -n -e " Omitiendo previsualización en $i segundos...   \r"
    read -t 1 -n 1 input && continuar=true && break
done

if [ "$continuar" = true ]; then
    echo -e "\nConfirmación recibida. Procediendo con la previsualización."
    convertir_png
    







    logs_dir="$ruta_directorio_bids/derivatives/logs"
    mkdir -p "$logs_dir"

    seleccion_txt="$logs_dir/seleccion.txt"
    lista_txt="$logs_dir/lista_imagenes_a_procesar_bet.txt"

    # --- Generar HTML inicial con imágenes originales ---
    generar_html_resultados "$ruta_directorio_bids"

    # --- Ingreso de correcciones manuales ---
    echo -e "\nIngresa el número del sujeto seguido del umbral de recorte (0-1) separado por espacio. Ejemplo:\n\n  05 0.45\n  12 0.55\n"
    echo "Cuando termines, presiona Ctrl+D para finalizar."

    > "$seleccion_txt"
    echo -e "\nIngreso correcciones personalizadas:\n"

    while read -r sujeto umbral; do
        if [[ $sujeto =~ ^[0-9]+$ && "$umbral" =~ ^0(\.[0-9]+)?$|^1(\.0*)?$ ]]; then
            [[ ${#sujeto} -eq 1 ]] && sujeto="0$sujeto"
            archivo_original=$(grep "sub-${sujeto}_T1w_crop" "$lista_txt")
            if [[ -n "$archivo_original" ]]; then


                dir_anat=$(dirname "$archivo_original")
                base_sin_crop=$(basename "$archivo_original" | sed 's/_crop//')
                archivo_salida="${dir_anat}/${base_sin_crop}_brain"




                echo "bet $archivo_original $archivo_salida -f $umbral" >> "$seleccion_txt"
                echo -e "${COLOR_EXITO}✔ Añadido: sub-${sujeto} con umbral $umbral${COLOR_NORMAL}"
            else
                echo -e "${COLOR_ERROR}✖ sub-${sujeto} no encontrado en lista. Saltando.${COLOR_NORMAL}"
            fi
        else
            echo -e "${COLOR_ERROR}✖ Entrada inválida: '$sujeto $umbral'. Usa formato: número_umbral (ej. 5 0.45)${COLOR_NORMAL}"
        fi
    done

    echo -e "\n📁 Archivo generado: $seleccion_txt"






















    #rm "$logs_dir"/lista_imagenes_a_procesar_bet.txt
else
    echo -e "\nNo se recibió respuesta. Previsualización BET cancelada."
fi

# Verifica si seleccion.txt existe y no está vacío
seleccion_txt="$logs_dir/seleccion.txt"
if [ -s "$seleccion_txt" ]; then
    procesar_seleccion
else
    echo -e "${COLOR_MODULO}No se aplicarán ajustes personalizados. seleccion.txt no existe o está vacío.${COLOR_NORMAL}"
fi
