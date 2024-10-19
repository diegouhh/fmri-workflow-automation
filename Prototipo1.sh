#!/bin/bash

#Realiza el recorte de cuello de un sujeto a la vez

# Exportar para usar X11 en lugar de Wayland (opcional,tuve errorres con los temas.)
export GDK_BACKEND=x11

COLOR_ERROR="\e[38;5;203m"    # Rojo claro
COLOR_WARNING="\e[38;5;190m"  # Amarillo claro
COLOR_SUCCESS="\e[38;5;154m"  # Verde claro
COLOR_MODULO="\e[38;5;99m"   # Dibide comandos principales
COLOR_NORMAL="\e[0m"          # Color normal


# Mensaje de introducción
echo -e "${COLOR_MODULO}=============================================="
echo -e "${COLOR_MODULO}   Automatización del Preprocesamiento de"
echo -e "${COLOR_MODULO}  Imágenes de Resonancia Magnética Funcional"
echo -e "${COLOR_MODULO}     (Utilizando robustfov, bet y FEAT)"
echo -e "${COLOR_MODULO}==============================================${COLOR_NORMAL}\n"

# Función que solicita la ruta del archivo en la terminal y verifica si el archivo existe con extensiones .nii o .nii.gz
solicitar_ruta_terminal(){
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


# Bucle para repetir el menú hasta que el usuario elija una opción válida
while true; do
    echo -e -n $'¿Cómo deseas ingresar los datos? \n\n- Interfaz gráfica (g)\n- Terminal (t)\n\nElige una opción (g/t): '
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
                        solicitar_ruta_terminal
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
                            solicitar_ruta_terminal
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
                            solicitar_ruta_terminal
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
        solicitar_ruta_terminal
        break  # Salir del bucle si la opción fue válida

    else
        echo -e "${COLOR_ERROR}\nOpción no válida. Por favor, ingresa 'g' o 't'. ${COLOR_NORMAL}"
        # El bucle continuará, repitiendo el menú
    fi
done

# Definir el nombre base para el archivo recortado
cropped_base_name="${input_image_path%%.*}_cropped.nii.gz"

# Comprobar si el archivo de salida ya existe y sobreescribir
if [ -f "$cropped_base_name" ]; then
    echo -e "${COLOR_WARNING}\nEl archivo ${cropped_base_name##*/} ya existe. Será sobrescrito.\n${COLOR_NORMAL}"
else   
    echo -e "\nEl archivo será guardado como ${cropped_base_name##*/}.\n"
fi

# Mensaje de inicio del proceso
sleep 0.5
echo -e "Recorte de cuello iniciado...\n"
# Ejecutar robustfov para realizar la operación
robustfov -i "$input_image_path" -r "$cropped_base_name"
sleep 0.2
# Mensaje de finalización
echo -e "${COLOR_SUCCESS}Resultado guardado en la ruta ${cropped_base_name} el día $(date)${COLOR_NORMAL}"
sleep 0.2
# Anuncio de inicio del BET
echo -e "${COLOR_MODULO}\nIniciando BET (Brain Extraction Tool)...\n${COLOR_NORMAL}"