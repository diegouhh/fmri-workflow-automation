#!/bin/bash

#Realiza el recorte de cuello de un suejto a la vez

# Exportar para usar X11 en lugar de Wayland (opcional,tuve errorres con los temas.)
export GDK_BACKEND=x11

COLOR_ERROR="\e[1;31m"
COLOR_NORMAL="\e[0m"


solicitar_ruta_terminal(){
    echo -e "Se usará el método alternativo de entrada por terminal."
    read -e -p "Introduce la ruta del archivo .nii o .nii.gz: " img_extract

    # Comprobar si el archivo existe con la extensión proporcionada o sin ella
    if [[ -f "$img_extract" ]]; then
        # El archivo existe con la ruta completa (incluyendo la extensión)
        echo -e "\nArchivo encontrado: ${img_extract##*/}"
    elif [[ -f "${img_extract}.nii" ]]; then
        # Añadir extensión .nii si existe
        img_extract="${img_extract}.nii"
        echo -e "\nArchivo encontrado: ${img_extract##*/}"
    elif [[ -f "${img_extract}.nii.gz" ]]; then
        # Añadir extensión .nii.gz si existe
        img_extract="${img_extract}.nii.gz"
        echo -e "\nArchivo encontrado: ${img_extract##*/}"
    else
        echo -e "\n${COLOR_ERROR}El archivo especificado no existe. Saliendo...${COLOR_NORMAL}"
        exit 1
    fi
}



#Preguntar al usuario qué ruta quiere seguir ¿Gráfica o vía terminal?
#-r y -n eliminan el salto de línea, para que se pueda ingresar el valor frente a la pregunta.
echo -e -n $'¿Cómo deseas ingresar los datos? \n\n- Interfaz gráfica (g)\n- Terminal (t)\n\nElige una opción (g/t): '
read -r metodo


if [[ "$metodo" == "g" || "$metodo" == "G" ]];then
    #Comprueba si Zenity está instalado, despreciando el output de ´command´
    if ! command -v zenity &> /dev/null; then
        echo -e "\nZenity no está instalado."

        #Preguntar si se quiere instalar Zenity
        read -p "Deseas instalar Zenity? (s/n)" instalar_zenity
        if [[ "$instalar_zenity" == "s" || "$instalar_zenity" == "S" ]]; then

            #Detecta la distro y usa el comando de instalación correspondiente
            if [[ -f /etc/arch-release ]]; then
                sudo pacman -S --noconfirm zenity  #Para Archlinux

            elif [[ -f /etc/debian_version ]]; then
                sudo apt-get update && sudo apt-get install -y zenity  # Para Ubuntu y Debian
            else   
                echo -e "${COLOR_ERROR}No se pudo detectar la distribución. Instala Zenity manualmente.${COLOR_NORMAL}"
                exit 1
            fi

            #Comprobar si zenity se instaló exitosamente, si no lo hizo, se ejecuta la el ingreso via terminal
            if ! command -v zenity &> /dev/null; then
            "La instalación de Zenity falló. Usando la entrada por terminal."
            solicitar_ruta_terminal
        fi
    else
        #Ruta directa vía terminal
        solicitar_ruta_terminal
        fi
    fi

    # Si  Zenity está instlado, solicitar la ruta del archivo mediante un cuadro de diálogo gráfico, depura por tipo de archivo, y elimina de la consola los archivos de error (Despreciables, por que son de GTK/compatiblidad con Wayland)
    if command -v zenity $>/dev/null; then
        echo -e "Selecciona un archivo .nii o .nii.gz."
        img_extract=$(zenity --file-selection --title="Selecciona un archivo .nii o .nii.gz" --filename="$HOME/" --file-filter="*.nii *.nii.gz" 2>/dev/null)

        # Comprobar si se seleccionó un archivo
        if [[ -z "$img_extract" ]]; then
            echo -e "${COLOR_ERROR}No se seleccionó ningún archivo. Saliendo...${COLOR_NORMAL}"
            exit 1
        fi
    fi

elif [[ "$metodo" == "t" || "$metodo" == "T" ]];then
    #Ruta directa vía terminal
    solicitar_ruta_terminal
else
    echo -e "${COLOR_ERROR}Opción no válida. Por favor, ingresa 'g' o 't'. ${COLOR_NORMAL}"
    exit 1
fi

#Remueve la extensión intermedia inducida por la forma de selección del archivo

# Definir el nombre base para el archivo recortado
img_cropped="${img_extract%%.*}_cropped"
output="$img_cropped"

# Comprobar si el archivo de salida ya existe
if [ -f "${output}.nii.gz" ]; then
    echo -e -n "\nEl archivo ${img_cropped##*/} ya existe."
    contador=1
    # Bucle para encontrar un nombre de archivo único
    while [ -f "${output}.nii.gz" ]; do
        echo -e -n "\nEl archivo ${img_cropped##*/}_${contador} ya existe."
        contador=$((contador+1))  # Incrementa el contador, sufijo en caso de existencia previa del recorte
        output="${img_cropped}_${contador}"  # Actualiza el nombre del archivo de salida
    done
    echo -e "\n\nLa extracción de cuello será guardada como ${img_cropped##*/}_${contador}.\n"
fi

# Mensaje de inicio del proceso
sleep 0.8
echo -e "Recorte de cuello iniciado...\n"
# Ejecutar robustfov para realizar la operación
robustfov -i "$img_extract" -r "$output"
sleep 0.2
# Mensaje de finalización
echo "Resultado guardado en la ruta ${output} el día $(date)"
