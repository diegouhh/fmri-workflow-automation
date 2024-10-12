#!/bin/bash

#Realiza el recorte de cuello de un suejto a la vez

# Exportar para usar X11 en lugar de Wayland (opcional,tuve errorres con los temas.)
export GDK_BACKEND=x11

# Solicitar la ruta del archivo mediante un cuadro de diálogo gráfico, depura por tipo de archivo, y elimina de la consola los archivos de error (Despreciables, por que son de GTK/compatiblidad con Wayland)
img_extract=$(zenity --file-selection --title="Selecciona un archivo .nii o .nii.gz" --filename="$HOME/" --file-filter="*.nii *.nii.gz" 2>/dev/null)

#Remueve la extensión intermedia inducida por la forma de selección del archivo
img_dir=${img_extract%%.*}

# Comprobar si se seleccionó un archivo
if [[ -z "$img_dir" ]]; then
    echo -e "\e[31mNo se seleccionó ningún archivo. Saliendo...\e[0m"
    exit 1
fi

# Definir el nombre base para el archivo recortado
img_cropped="${img_dir}_cropped"
contador=1
output="$img_cropped"

# Comprobar si el archivo de salida ya existe
if [ -f "${output}.nii.gz" ]; then
    # Bucle para encontrar un nombre de archivo único
    while [ -f "${output}.nii.gz" ]; do
        echo -e "\nEl archivo $img_cropped ya existe."
        echo "La extracción de cuello será guardada como ${img_cropped}_${contador}.\n"
        output="${img_cropped}_${contador}"  # Actualiza el nombre del archivo de salida
        contador=$((contador+1))  # Incrementa el contador
    done
fi

# Mensaje de inicio del proceso
sleep 0.8
echo "Recorte de cuello iniciado..."
# Ejecutar robustfov para realizar la operación
robustfov -i "$img_dir" -r "$output"
sleep 0.2
# Mensaje de finalización
echo "Resultado guardado en la ruta $output el día $(date)"
