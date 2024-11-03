#!/bin/bash

# ==================================================================================
# Título: Pipeline de Procesamiento task-fMRI
# Autores: Juan Diego Ortega Álvarez, Juan José Sierra Peña. - Bioingeniería.
# Fecha de Creación: 31 de Octubre de 2024
# Descripción:
# Este script automatiza el procesamiento de imágenes de resonancia magnética 
# funcional en tarea (task-fMRI) usando herramientas especializadas como `robustfov`, `bet` y 
# `FEAT`. Permite realizar el recorte de la región del cuello, extraer el cerebro 
# y configurar un flujo de trabajo automatizado para el preprocesamiento de fMRI.
#
# El script ofrece opciones para seleccionar archivos tanto de forma gráfica 
# como desde la terminal, asegurando la correcta ejecución de cada proceso y 
# confirmando la instalación de herramientas como `Zenity` para la selección 
# gráfica de archivos, si es necesario.
#
# Ejemplo de Uso:
# 1. Clona el repositorio y accede a la carpeta:
#    git clone https://github.com/diegouhh/fmri-workflow-automation.git
#    cd fmri-workflow-automation
# 2. Otorga permisos de ejecución al script:
#    chmod +x fmri_processing_pipeline.sh
# 3. Ejecuta el script:
#    ./fmri_processing_pipeline.sh
#
# Requisitos:
# - Linux o sistema operativo basado en Unix con Bash.
# - FSL (incluye las herramientas robustfov, bet y FEAT).
# - Opcional: Zenity para la selección gráfica de archivos.
#
# Próximas Funcionalidades:
# - Procesamiento en lote de múltiples imágenes en una sola ejecución.
# - Optimización para detectar y omitir el procesamiento si ya existen archivos _crop.
# - Compatibilidad con el estándar BIDS para organizar los resultados en carpetas de derivados.
#
# ==================================================================================

COLOR_ERROR="\e[38;5;203m"    # Rojo claro
COLOR_WARNING="\e[38;5;190m"  # Amarillo claro
COLOR_SUCCESS="\e[38;5;154m"  # Verde claro
COLOR_MODULO="\e[38;5;99m"    # Divide comandos principales
COLOR_NORMAL="\e[0m"          # Color normal


# Mensaje de introducción
echo -e "${COLOR_MODULO}=============================================="
echo -e "${COLOR_MODULO}   Automatización del Preprocesamiento de"
echo -e "${COLOR_MODULO}  Imágenes de Resonancia Magnética Funcional"
echo -e "${COLOR_MODULO}     (Utilizando robustfov, bet y FEAT)"
echo -e "${COLOR_MODULO}==============================================${COLOR_NORMAL}\n"

# Función que solicita la ruta del archivo en la terminal y verifica si el archivo existe con extensiones .nii o .nii.gz
solicitar_ruta_terminal_individual(){
    echo -e "Se usará el método alternativo de entrada por terminal."
    read -e -p "Introduce la ruta del archivo .nii o .nii.gz: " input_image_path

    # Comprobar si el archivo existe con la extensión proporcionada o sin ella
    if [[ -f "$input_image_path" ]]; then

        # El archivo existe con la ruta completa (incluyendo la extensión)
        echo -e "${COLOR_SUCCESS}\nArchivo encontrado: ${input_image_path##*/}${COLOR_NORMAL}"
    elif [[ -f "${input_image_path}.nii" ]]; then

        # Añadir extensión .nii si existe
        input_image_path="${input_image_path}.nii"
        echo -e "${COLOR_SUCCESS}\nArchivo encontrado: ${input_image_path##*/}${COLOR_NORMAL}"
    elif [[ -f "${input_image_path}.nii.gz" ]]; then

        # Añadir extensión .nii.gz si existe
        input_image_path="${input_image_path}.nii.gz"
        echo -e "${COLOR_SUCCESS}\nArchivo encontrado: ${input_image_path##*/}${COLOR_NORMAL}"
    else
        echo -e "${COLOR_ERROR}\nFormato de archivo no reconocido. Debe ser .nii o .nii.gz. Saliendo...${COLOR_NORMAL}"
        exit 1
    fi
}


solicitar_ruta_terminal_bids(){
    echo -e "Se usará el método de entrada por terminal."
    read -e -p "Introduce la ruta del directorio BIDS: " directorio_bids

    # Comprobar si el directorio existe.
    if [[ -d "$directorio_bids" ]]; then
        echo -e "${COLOR_SUCCESS}\nDirectorio encontrado: ${directorio_bids}${COLOR_NORMAL}"
    else 
        echo -e "${COLOR_ERROR}\nDirectorio no encontrado. Saliendo...${COLOR_NORMAL}"
        exit 1    
    fi   
}

procesar_archivo_bids(){

    echo -e "${COLOR_MODULO}Iniciando procesamiento en paralelo...${COLOR_NORMAL}"

    # Encontrar archivos *_T1w.nii o *_T1w.nii.gz y procesarlos en paralelo
    find "$directorio_bids" -type f -path "*/sub-*/anat/*_T1w.nii*" > "$directorio_bids"/imagenes_a_procesar.txt

    # Quitar las extensiones .nii o .nii.gz de cada linea en imagenes_a_procesar.txt
    sed -i -E 's/\.(nii|nii\.gz)$//' "$directorio_bids"/imagenes_a_procesar.txt

    while read line; do
        output_file="${line}_crop*"

        # Si el archivo de salida ya existe, eliminarlo
        [ -f "$output_file" ] && rm "$output_file"
    done < "$directorio_bids/imagenes_a_procesar.txt"


    # Ejecuta robustfov en paralelo con xargs y 4 procesos
    cat "$directorio_bids"/imagenes_a_procesar.txt | xargs -P 4 -I {} robustfov -i {} -r "{}_crop.nii.gz"

    # Eliminar el archivo imagenes_a_procesar.txt después de terminar el procesamiento
    rm "$directorio_bids/imagenes_a_procesar.txt"

    echo -e "${COLOR_SUCCESS}Recorte de cuello terminado.${COLOR_SUCCESS}"
}

while true; do
# Menú para elegir entre BIDS o archivo individual
echo -e -n $'¿Deseas procesar un archivo individual o trabajar con un directorio BIDS?\n\n- Archivo individual (i)\n- Directorio BIDS (b)\n\nElige una opción (i/b): '
read -r opcion

# Procesamiento individual
if [[ "$opcion" == "i" || "$opcion" == I ]]; then  
    # Bucle para repetir el menú hasta que el usuario elija una opción válida
    while true; do
        echo -e -n $'\n¿Cómo deseas ingresar los datos? \n\n- Interfaz gráfica (g)\n- Terminal (t)\n\nElige una opción (g/t): '
        read -r metodo

        if [[ "$metodo" == "g" || "$metodo" == "G" ]]; then
            # Comprueba si Zenity está instalado, despreciando el output de ´command´
            if ! command -v zenity &> /dev/null; then
                echo -e "${COLOR_WARNING}\nZenity no está instalado.${COLOR_NORMAL}"

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
                                input_image_path=$(zenity --file-selection --title="Selecciona un archivo .nii o .nii.gz" --filename="$HOME/" --file-filter="*.nii *.nii.gz" 2>/dev/null)

                                # Comprobar si se seleccionó un archivo
                                if [[ -z "$input_image_path" ]]; then
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
                input_image_path=$(zenity --file-selection --title="Selecciona un archivo .nii o .nii.gz" --filename="$HOME/" --file-filter="*.nii *.nii.gz" 2>/dev/null)

                # Comprobar si se seleccionó un archivo
                if [[ -z "$input_image_path" ]]; then
                    echo -e "${COLOR_ERROR}No se seleccionó ningún archivo. Saliendo...${COLOR_NORMAL}"
                    exit 1
                fi
            fi
            break  # Salir del bucle si la opción fue válida

        elif [[ "$metodo" == "t" || "$metodo" == "T" ]]; then
            # Ruta directa vía terminal
            solicitar_ruta_terminal_individual
            break  # Salir del bucle si la opción fue válida

        else
            echo -e "${COLOR_ERROR}\nOpción no válida. Por favor, ingresa 'g' o 't'. ${COLOR_NORMAL}"
            # El bucle continuará, repitiendo el menú
        fi
    done

    # Definir el nombre base para el archivo recortado
    crop_base_name="${input_image_path%%.*}_crop.nii.gz"

    # Comprobar si el archivo de salida ya existe y sobreescribir
    if [ -f "$crop_base_name" ]; then
        echo -e "${COLOR_WARNING}\nEl archivo ${crop_base_name##*/} ya existe. Será sobrescrito.\n${COLOR_NORMAL}"
    else   
        echo -e "\nEl archivo será guardado como ${crop_base_name##*/}.\n"
    fi

    # Mensaje de inicio del proceso
    echo -e "Recorte de cuello iniciado...\n"
    # Ejecutar robustfov para realizar la operación
    robustfov -i "$input_image_path" -r "$crop_base_name"
    # Mensaje de finalización
    echo -e "${COLOR_SUCCESS}Resultado guardado en la ruta ${crop_base_name} el día $(date)${COLOR_NORMAL}"
    break

# ----------------------------------------------------------------------------------------------------------------------------- #

# Procesamiento en BIDS (ROBUSTFOV)
elif [[ "$opcion" == "b" || "$opcion" == "B" ]]; then
    while true; do
            echo -e -n $'\n¿Cómo deseas ingresar los datos? \n\n- Interfaz gráfica (g)\n- Terminal (t)\n\nElige una opción (g/t): '
            read -r metodo

            if [[ "$metodo" == "g" || "$metodo" == "G" ]]; then
            # Comprueba si Zenity está instalado, despreciando el output de ´command´
            if ! command -v zenity &> /dev/null; then
                echo -e "${COLOR_WARNING}\nZenity no está instalado.${COLOR_NORMAL}"

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
                                echo -e "Selecciona un directorio en estándar BIDS."
                                directorio_bids=$(zenity --file-selection --directory --title="Selecciona un directorio en estándar BIDS" --filename="$HOME/" 2>/dev/null)

                                # Comprobar si se seleccionó un archivo
                                if [[ -z "$directorio_bids" ]]; then
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
                echo -e "Selecciona un directorio en estándar BIDS."
                directorio_bids=$(zenity --file-selection --directory --title="Selecciona un directorio en estándar BIDS" --filename="$HOME/" 2>/dev/null)

                # Comprobar si se seleccionó un directorio
                if [[ -z "$directorio_bids" ]]; then
                    echo -e "${COLOR_ERROR}No se seleccionó ningún directorio. Saliendo...${COLOR_NORMAL}"
                    exit 1
                fi
            fi
            break  # Salir del bucle si la opción fue válida (se lleva el nombre del directorio)

        elif [[ "$metodo" == "t" || "$metodo" == "T" ]]; then
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
echo -e "${COLOR_MODULO}\nIniciando BET (Brain Extraction Tool)...\n${COLOR_NORMAL}"

# Procesamiento individual (ROBUSTFOV)

