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
COLOR_ADVERTENCIA="\e[38;5;190m"  # Amarillo claro
COLOR_EXITO="\e[38;5;154m"  # Verde claro
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
    read -e -p "Introduce la ruta del archivo .nii o .nii.gz: " ruta_imagen

    # Comprobar si el archivo existe con la extensión proporcionada o sin ella
    if [[ -f "$ruta_imagen" ]]; then

        # El archivo existe con la ruta completa (incluyendo la extensión)
        echo -e "${COLOR_EXITO}\nArchivo encontrado: ${ruta_imagen##*/}${COLOR_NORMAL}"
    elif [[ -f "${ruta_imagen}.nii" ]]; then

        # Añadir extensión .nii si existe
        ruta_imagen="${ruta_imagen}.nii"
        echo -e "${COLOR_EXITO}\nArchivo encontrado: ${ruta_imagen##*/}${COLOR_NORMAL}"
    elif [[ -f "${ruta_imagen}.nii.gz" ]]; then

        # Añadir extensión .nii.gz si existe
        ruta_imagen="${ruta_imagen}.nii.gz"
        echo -e "${COLOR_EXITO}\nArchivo encontrado: ${ruta_imagen##*/}${COLOR_NORMAL}"
    else
        echo -e "${COLOR_ERROR}\nFormato de archivo no reconocido. Debe ser .nii o .nii.gz. Saliendo...${COLOR_NORMAL}"
        exit 1
    fi
}


solicitar_ruta_terminal_bids(){
    echo -e "Se usará el método de entrada por terminal."
    read -e -p "Introduce la ruta del directorio BIDS: " ruta_directorio_bids

    # Comprobar si el directorio existe.
    if [[ -d "$ruta_directorio_bids" ]]; then
        echo -e "${COLOR_EXITO}\nDirectorio encontrado: ${ruta_directorio_bids}${COLOR_NORMAL}"
    else 
        echo -e "${COLOR_ERROR}\nDirectorio no encontrado. Saliendo...${COLOR_NORMAL}"
        exit 1    
    fi   
}

procesar_archivo_bids(){

    echo -e "Iniciando procesamiento en paralelo..."

    # Encontrar archivos *_T1w.nii o *_T1w.nii.gz y almacenarlos
    find "$ruta_directorio_bids" -type f -path "*/sub-*/anat/*_T1w.nii*" > "$ruta_directorio_bids"/lista_imagenes_a_procesar_robustfov.txt

    # Quitar las extensiones .nii o .nii.gz de cada linea en lista_imagenes_a_procesar_robustfov.txt
    sed -i -E 's/\.(nii|nii\.gz)$//' "$ruta_directorio_bids"/lista_imagenes_a_procesar_robustfov.txt

    while read line; do
        archivo_salida="${line}_crop*"

        # Si el archivo de salida ya existe, eliminarlo
        [ -f "$archivo_salida" ] && rm "$archivo_salida"
    done < "$ruta_directorio_bids/lista_imagenes_a_procesar_robustfov.txt"

    # Ejecuta robustfov en paralelo con xargs y 4 procesos
    echo -e "${COLOR_MODULO}Iniciando la reducción del FOV (Robustfov)${COLOR_NORMAL}"    
    cat "$ruta_directorio_bids"/lista_imagenes_a_procesar_robustfov.txt | xargs -P 4 -I {} robustfov -i {} -r "{}_crop.nii.gz"

    # Eliminar el archivo lista_imagenes_a_procesar_robustfov.txt después de terminar el procesamiento
    rm "$ruta_directorio_bids/lista_imagenes_a_procesar_robustfov.txt"

    echo -e "${COLOR_EXITO}Reducción del FOV terminada.${COLOR_EXITO}"
}

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

# ----------------------------------------------------------------------------------------------------------------------------- #

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
                                echo -e "Selecciona un directorio en estándar BIDS."
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
                echo -e "Selecciona un directorio en estándar BIDS."
                ruta_directorio_bids=$(zenity --file-selection --directory --title="Selecciona un directorio en estándar BIDS" --filename="$HOME/" 2>/dev/null)

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
echo -e "${COLOR_MODULO}\nIniciando BET (Brain Extraction Tool).\n${COLOR_NORMAL}"

# Verifica si nombre_base_crop está definido y no vacío (si no está vacío indica que se siguió la ruta individual.)

# ==================================================================================
# BET individual
# ==================================================================================
if [ ! -z "$nombre_base_crop" ]; then
    # Define la ruta de salida para el archivo de salida del BET, eliminando la extensión
    nombre_salida_bet="${nombre_base_crop%%.*}_brain.nii.gz"
    echo "Procesando BET en ruta individual para: $nombre_base_crop"
    bet "$nombre_base_crop" "$nombre_salida_bet" -f 0.5
    # Mensaje indicando que el proceso en ruta individual ha finalizado
    echo -e "${COLOR_EXITO}Proceso BET completado para: $nombre_base_crop.${COLOR_NORMAL}"

else 
# ==================================================================================
# BET BIDS
# ==================================================================================
    # Busca todos los archivos *_crop.nii en el directorio BIDS y los guarda en un archivo de lista
    find "$ruta_directorio_bids" -type f -path "*/sub-*/anat/*_crop.nii*" > "$ruta_directorio_bids"/lista_imagenes_a_procesar_bet.txt
    # Quita las extensiones .nii o .nii.gz de cada linea en lista_imagenes_a_procesar_bet.txt
    sed -i -E 's/\.(nii|nii\.gz)$//' "$ruta_directorio_bids"/lista_imagenes_a_procesar_bet.txt
    

    # Revisa cada línea de la lista para determinar si los archivos de salida existen
    while read line; do
        archivo_salida_bet="${line}_brain*"

        # Si el archivo de salida ya existe, eliminarlo
        [ -f "$archivo_salida_bet" ] && rm "$archivo_salida_bet"
    done < "$ruta_directorio_bids/lista_imagenes_a_procesar_bet.txt"


    # Mensaje indicando que el procesamiento se ha iniciado
    echo "Procesamiento BET en curso..."

    # Ejecuta el comando BET en paralelo
    cat "$ruta_directorio_bids"/lista_imagenes_a_procesar_bet.txt | xargs -P 5 -I {} bet {} "{}_brain.nii.gz"

    # Eliminar el archivo lista_imagenes_a_procesar_bet.txt después de terminar el procesamiento
    rm "$ruta_directorio_bids/lista_imagenes_a_procesar_bet.txt"

# Mensaje indicando que el proceso ha finalizado
    echo -e "${COLOR_EXITO}Extracción de cerebro terminada para todos los archivos.${COLOR_EXITO}"

fi

