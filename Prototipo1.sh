#!/bin/bash

# ==================================================================================
# Título: Pipeline de Procesamiento task-fMRI
# Autores: Juan Diego Ortega Álvarez, Juan José Sierra Peña. - Bioingeniería.
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

# Variables de color (mostrados en la terminal)
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
    # Usa 'read' para solicitar la ruta del archivo, permitiendo la navegación con tabulación (-e) y mostrando el prompt de solicitud.
    read -e -p "Introduce la ruta del archivo .nii o .nii.gz: " ruta_imagen

        # Comienza la verificación de si el archivo existe y tiene el formato adecuado.
        if [[ -f "$ruta_imagen" ]]; then

        # Si el archivo existe con la ruta completa, se muestra un mensaje de confirmación.
            echo -e "${COLOR_EXITO}\nArchivo encontrado: ${ruta_imagen##*/}${COLOR_NORMAL}"
    # Si el archivo no se encuentra, intenta agregar la extensión .nii y verifica su existencia.
    elif [[ -f "${ruta_imagen}.nii" ]]; then
        ruta_imagen="${ruta_imagen}.nii" # Agrega la extensión .nii a la variable de ruta.
        echo -e "${COLOR_EXITO}\nArchivo encontrado: ${ruta_imagen##*/}${COLOR_NORMAL}"
    # Si tampoco se encuentra con .nii, intenta agregar .nii.gz y verifica nuevamente.
    elif [[ -f "${ruta_imagen}.nii.gz" ]]; then 
        ruta_imagen="${ruta_imagen}.nii.gz"  # Agrega la extensión .nii.gz si existe
        echo -e "${COLOR_EXITO}\nArchivo encontrado: ${ruta_imagen##*/}${COLOR_NORMAL}"
    else
        # Si el archivo no existe en ninguno de los formatos, muestra un mensaje de error y termina el script.
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

    echo -e "Iniciando procesamiento en paralelo."

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
    echo -e "Reducción del FOV en curso..."
    cat "$ruta_directorio_bids"/lista_imagenes_a_procesar_robustfov.txt | xargs -P 5 -I {} robustfov -i {} -r "{}_crop.nii.gz" >/dev/null

    # Eliminar el archivo lista_imagenes_a_procesar_robustfov.txt después de terminar el procesamiento
    rm "$ruta_directorio_bids/lista_imagenes_a_procesar_robustfov.txt"

    echo -e "${COLOR_EXITO}Reducción del FOV terminada para todos los archivos.${COLOR_EXITO}"
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
echo -e "${COLOR_MODULO}\nIniciando BET (Brain Extraction Tool).${COLOR_NORMAL}"

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
    echo "BET en curso..."

    # Ejecuta el comando BET en paralelo
    cat "$ruta_directorio_bids"/lista_imagenes_a_procesar_bet.txt | xargs -P 5 -I {} bet {} "{}_brain.nii.gz"


# Mensaje indicando que el proceso ha finalizado
    echo -e "${COLOR_EXITO}Extracción de cerebro terminada para todos los archivos.${COLOR_NORMAL}"

fi

# ==================================================================================
# Conversión de NIfTI a PNG después del BET
# ==================================================================================
convertir_png(){
    echo -e "${COLOR_MODULO}\nConvirtiendo archivos procesados a formato PNG.\n${COLOR_NORMAL}"

    # Crea el directorio de resultados si no existe
    mkdir -p "$ruta_directorio_bids/derivatives/png_converted"

    # Si es un archivo individual
    if [ ! -z "$nombre_salida_bet" ]; then
        nombre_png="$ruta_directorio_bids/derivatives/png_converted/$(basename "${nombre_salida_bet%%.*}").png"
        slicer "$nombre_salida_bet" -a "$nombre_png"
        echo -e "${COLOR_EXITO}Imagen convertida a PNG: $nombre_png${COLOR_NORMAL}"

    # Si es un conjunto de archivos
    else
        find "$ruta_directorio_bids" -type f -path "*/sub-*/anat/*_crop_brain.nii*" > "$ruta_directorio_bids/lista_imagenes_a_procesar_bet_html.txt"
        sed -i -E 's/\.(nii|nii\.gz)$//' "$ruta_directorio_bids/lista_imagenes_a_procesar_bet_html.txt"

        while read -r line; do
            nombre_png="$ruta_directorio_bids/derivatives/png_converted/$(basename "${line%%.*}").png"
            slicer "$line" -a "$nombre_png"
        done < "$ruta_directorio_bids/lista_imagenes_a_procesar_bet_html.txt"

        echo -e "${COLOR_EXITO}Conversión de imágenes a png exitosa ${COLOR_NORMAL}"

        rm "$ruta_directorio_bids/lista_imagenes_a_procesar_bet_html.txt"
    fi
}

generar_html_resultados(){
    ruta_html="$ruta_directorio_bids/derivatives/png_converted/resultados_bet.html"
    echo -e "<!DOCTYPE html>\n<html lang='es'>\n<head>\n<meta charset='UTF-8'>\n<title>Resultados de BET - Revisión de Recorte</title>" > "$ruta_html"
    echo "<style>
            body { font-family: Arial, sans-serif; margin: 20px; background-color: #f4f4f9; color: #333; }
            h1 { color: #333; text-align: center; }
            p.instructions { text-align: center; font-size: 1em; color: #555; margin-top: -10px; margin-bottom: 20px; }
            .gallery { display: flex; flex-wrap: wrap; gap: 15px; justify-content: center; }
            .gallery-item { width: 300px; text-align: center; }
            .gallery-item img { width: 100%; height: auto; border: 2px solid #ddd; border-radius: 5px; cursor: pointer; }
            .footer { text-align: center; margin-top: 30px; font-size: 0.8em; color: #777; }
            /* Modal para vista previa */
            .modal { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background-color: rgba(0, 0, 0, 0.8); justify-content: center; align-items: center; z-index: 10; }
            .modal-content { max-width: 90%; max-height: 90%; display: flex; align-items: center; justify-content: center; }
            .modal-content img { width: 100%; height: auto; max-width: none; transform: scale(1.5); }
            .close { position: absolute; top: 20px; right: 30px; font-size: 30px; color: white; cursor: pointer; font-weight: bold; }
        </style></head><body>" >> "$ruta_html"

    echo -e "<h1>Resultados de BET - Revisión de Recorte</h1>" >> "$ruta_html"
    echo -e "<p class='instructions'>Revise cada imagen y decida si el recorte es adecuado. Haga clic en una imagen para verla en tamaño completo.<br>
        Ajuste el parámetro <code>-f</code> en BET para recortar más o menos cráneo según sea necesario.</p>" >> "$ruta_html"
    echo -e "<div class='gallery'>" >> "$ruta_html"

    # Agrega las imágenes a la galería con checkboxes
    for img in "$ruta_directorio_bids/derivatives/png_converted"/*.png; do
        nombre_archivo=$(basename "$img")
        echo -e "<div class='gallery-item'>
                    <input type='checkbox' id='$nombre_archivo' name='imagen_seleccionada' value='$nombre_archivo'>
                    <label for='$nombre_archivo'><a href='$img' target='_blank'>$nombre_archivo</a></label>
                    <br>
                    <img src='$img' alt='$nombre_archivo' onclick='openModal(\"$img\")'>
                </div>" >> "$ruta_html"
    done

    echo -e "</div>" >> "$ruta_html"

    # Modal para vista previa
    echo -e "<div class='modal' id='imageModal'>
            <span class='close' onclick='closeModal()'>&times;</span>
            <div class='modal-content'>
                <img id='modalImage' src=''>
            </div>
            </div>" >> "$ruta_html"

    echo -e "<div class='footer'>Generado automáticamente por el script de conversión de imágenes. <br>
        Puede ajustar el parámetro <code>-f</code> en BET para controlar el nivel de recorte de cada imagen.</div>" >> "$ruta_html"

    # JavaScript para abrir y cerrar la modal
    echo -e "<script>
            function openModal(src) {
                document.getElementById('modalImage').src = src;
                document.getElementById('imageModal').style.display = 'flex';
            }
            function closeModal() {
                document.getElementById('imageModal').style.display = 'none';
            }
            </script>" >> "$ruta_html"

    echo -e "</body>\n</html>" >> "$ruta_html"

    echo -e "${COLOR_EXITO}HTML generado en: $ruta_html${COLOR_NORMAL}"



    # Abre el HTML en el navegador
    xdg-open "$ruta_html"

    # Espera que el usuario ingrese los nombres seleccionados
    echo -e "Revisa el HTML y selecciona las imágenes a cambiar. Ingresa el número del archivo sin extensión seguido de + o -, separados por comas."
    read -p "Ingresa tu selección: " seleccion_input

    # Define la ruta para guardar las selecciones con el parámetro adecuado
    seleccion_txt="$ruta_directorio_bids/derivatives/png_converted/seleccion.txt"
    touch "$seleccion_txt" # Crea el archivo seleccion.txt

    # Elimina espacios y convierte las comas en saltos de línea para procesar cada entrada
    seleccion_input=$(echo "$seleccion_input" | sed 's/ //g') # Quita espacios en blanco
    selecciones=$(echo "$seleccion_input" | tr ',' '\n') # Convierte comas en saltos de línea
    
# Procesa cada selección y escribe en seleccion.txt con el formato especificado
for seleccion in $selecciones; do
    if [[ $seleccion =~ ^[0-9]+[+-]$ ]]; then
        archivo_numero=${seleccion%?}   # Obtiene el número del archivo sin el signo
        signo=${seleccion: -1}          # Obtiene el último carácter como signo (+ o -)

        # Agrega un cero al inicio si el número es de un solo dígito
        if [[ ${#archivo_numero} -eq 1 ]]; then
            archivo_numero="0$archivo_numero"
        fi

        # Busca en lista_imagenes_a_procesar_bet.txt
        archivo_original=$(grep "sub-${archivo_numero}_T1w_crop" "$ruta_directorio_bids/lista_imagenes_a_procesar_bet.txt")

        if [[ -n $archivo_original ]]; then
            archivo_salida="${ruta_directorio_bids}/derivatives/png_converted/$(basename "$archivo_original")_brain"

            if [[ $signo == "+" ]]; then
                echo "$archivo_original $archivo_salida -f 0.6" >> "$seleccion_txt"
            elif [[ $signo == "-" ]]; then
                echo "$archivo_original $archivo_salida -f 0.4" >> "$seleccion_txt"
            fi
        else
            echo "El archivo $archivo_numero no existe en lista_imagenes_a_procesar_bet.txt. Se realizará nuevamente el BET para los demás."
        fi
    else
        echo "Advertencia: Entrada '$seleccion' no válida. Asegúrate de usar el formato correcto (número seguido de + o -)."
    fi
done


    echo -e "Tu selección fue guardada en: $seleccion_txt"
    
}

# ==================================================================================
# Confirmación de conversión con cuenta regresiva
# ==================================================================================
echo -e "\n" # Salto de línea para mejor estructura de la salida terminal 
echo "Presiona cualquier tecla para confirmar la conversión de imágenes"
# Contador regresivo para mostrar en la terminal
for ((i=60; i>0; i--)); do
    echo -n -e " Procederemos en $i segundos...   \r"
    read -t 1 -n 1 input && continuar=true && break
done

if [ "$continuar" = true ]; then
    echo -e "\nConfirmación recibida. Procediendo con la conversión de imágenes."
    convertir_png
    generar_html_resultados
    rm "$ruta_directorio_bids"/lista_imagenes_a_procesar_bet.txt
else
    echo -e "\nNo se recibió respuesta. Conversión de imágenes cancelada."
fi
