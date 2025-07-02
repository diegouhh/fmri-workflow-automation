#!/bin/bash
# ============================
# FUNCIONES DE ENTRADA
# ============================

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

# ============================
# FUNCIONES DE PROCESAMIENTO
# ============================

procesar_archivo_bids(){
    logs_dir="$ruta_directorio_bids/derivatives/logs"
    mkdir -p "$logs_dir"

    echo -e "Iniciando procesamiento en paralelo."

    # Encontrar archivos *_T1w.nii o *_T1w.nii.gz y almacenarlos
    find "$ruta_directorio_bids" -type f -path "*/sub-*/anat/*_T1w.nii*" > "$logs_dir/lista_imagenes_a_procesar_robustfov.txt"

    # Quitar las extensiones .nii o .nii.gz de cada linea en lista_imagenes_a_procesar_robustfov.txt
    sed -i -E 's/\.(nii|nii\.gz)$//' "$logs_dir/lista_imagenes_a_procesar_robustfov.txt"


    while read line; do
        archivo_salida="${line}_crop*"

        # Si el archivo de salida ya existe, eliminarlo
        [ -f "$archivo_salida" ] && rm "$archivo_salida"
    done < "$logs_dir/lista_imagenes_a_procesar_robustfov.txt"

    # Ejecuta robustfov en paralelo con xargs y 4 procesos
    echo -e "${COLOR_MODULO}Iniciando la reducción del FOV (Robustfov)${COLOR_NORMAL}"    
    echo -e "Reducción del FOV en curso..."
    cat "$logs_dir"/lista_imagenes_a_procesar_robustfov.txt | xargs -P "${procesos_paralelos}" -I {} robustfov -i {} -r "{}_crop.nii.gz" >/dev/null

    # Eliminar el archivo lista_imagenes_a_procesar_robustfov.txt después de terminar el procesamiento
    #rm "$ruta_directorio_bids/lista_imagenes_a_procesar_robustfov.txt"  💫💫💫💫💫💫

    echo -e "${COLOR_EXITO}Reducción del FOV terminada para todos los archivos.${COLOR_EXITO}"
}


###################CORRECCIONESSSSSSSSSSSSSSSS#################################
#################ejecutar solo si existe el seleccion.txt######################
####################Correción tiempor de conversión a png. si existen los archivos? ##
procesar_seleccion() {
    logs_dir="$ruta_directorio_bids/derivatives/logs"
    mkdir -p "$logs_dir"

    echo -e "${COLOR_MODULO}\nAplicando ajustes personalizados con BET según seleccion.txt\n${COLOR_NORMAL}"

    seleccion_txt="$logs_dir/seleccion.txt"

    if [ ! -f "$seleccion_txt" ]; then
        echo -e "${COLOR_ERROR}No se encontró el archivo seleccion.txt en: $seleccion_txt${COLOR_NORMAL}"
        return 1
    fi

    archivos_salida=()

    # 1. Ejecutar todos los comandos BET
    while IFS= read -r linea; do
        $linea &>/dev/null
        if [ $? -eq 0 ]; then
            archivo_salida=$(echo "$linea" | awk '{print $3}')
            archivos_salida+=("${archivo_salida}.nii.gz")
        fi
    done < "$seleccion_txt"

    # 2. Esperar silenciosamente a que se generen los archivos BET resultantes
    for archivo in "${archivos_salida[@]}"; do
        for intento in {1..20}; do
            [ -s "$archivo" ] && break
            sleep 0.5
        done
    done

    # 3. Generar PNGs desde los resultados del BET
    echo -e "${COLOR_MODULO}Convirtiendo archivos procesados a formato PNG.${COLOR_NORMAL}"
    mkdir -p "$ruta_directorio_bids/derivatives/png_converted"

    for archivo in "${archivos_salida[@]}"; do
        [ ! -f "$archivo" ] && continue
        nombre_base=$(basename "${archivo%.nii.gz}" | sed 's/_crop//')
        png_path="$ruta_directorio_bids/derivatives/png_converted/${nombre_base}.png"

        if [ -f "$png_path" ]; then
            mv "$png_path" "${png_path%.png}_old.png"
        fi
        slicer "$archivo" -a "$png_path" &>/dev/null
    done

    echo -e "${COLOR_EXITO}Conversión de imágenes a png exitosa${COLOR_NORMAL}"

    # 4. Regenerar HTML
    generar_html_resultados "$ruta_directorio_bids"
}










# ============================
# FUNCIONES MiSCELEANEO
# ============================

# Conversión de NIfTI a PNG después del BET
convertir_png(){
    logs_dir="$ruta_directorio_bids/derivatives/logs"
    mkdir -p "$logs_dir"

    echo -e "${COLOR_MODULO}\nConvirtiendo archivos procesados a formato PNG.\n${COLOR_NORMAL}"

    mkdir -p "$ruta_directorio_bids/derivatives/png_converted"

    # Si es un archivo individual
    if [ ! -z "$nombre_salida_bet" ]; then
        nombre_base_sin_crop="$(basename "${nombre_salida_bet%%.*}" | sed 's/_crop//')"
        nombre_png="$ruta_directorio_bids/derivatives/png_converted/${nombre_base_sin_crop}.png"
        slicer "$nombre_salida_bet" -a "$nombre_png"
        echo -e "${COLOR_EXITO}Imagen convertida a PNG: $nombre_png${COLOR_NORMAL}"

    # Si es un conjunto de archivos
    else
        find "$ruta_directorio_bids" -type f -path "*/sub-*/anat/*_brain.nii*" > "$logs_dir/lista_imagenes_a_procesar_bet_html.txt"
        sed -i -E 's/\.(nii|nii\.gz)$//' "$logs_dir/lista_imagenes_a_procesar_bet_html.txt"

        while read -r line; do
            ruta_completa="${line}.nii.gz"
            [ -f "$line.nii" ] && ruta_completa="${line}.nii"
            nombre_base_sin_crop="$(basename "${line}" | sed 's/_crop//')"
            nombre_png="$ruta_directorio_bids/derivatives/png_converted/${nombre_base_sin_crop}.png"
            slicer "$ruta_completa" -a "$nombre_png"
        done < "$logs_dir/lista_imagenes_a_procesar_bet_html.txt"

        echo -e "${COLOR_EXITO}Conversión de imágenes a png exitosa ${COLOR_NORMAL}"
    fi
}

generar_html_resultados() {
    # Ruta base BIDS y HTML de salida
    local ruta_directorio_bids="$1"
    local ruta_html="$ruta_directorio_bids/derivatives/png_converted/resultados_bet.html"
    local logs_dir="$ruta_directorio_bids/derivatives/logs"

    # Asegura que exista el directorio de logs y limpia HTML anterior
    mkdir -p "$logs_dir"
    rm -f "$ruta_html"
    touch "$ruta_html"

    # Crea la cabecera HTML, con estilos CSS y título de la página
    {
        echo "<!DOCTYPE html>
<html lang='es'>
<head>
<meta charset='UTF-8'>
<title>Resultados de BET - Revisión de Recorte</title>
<style>
    body { font-family: Arial; margin: 20px; background: #f4f4f9; color: #333; }
    h1, .instructions, .footer { text-align: center; }
    .instructions { color: #555; margin: -10px 0 20px; }
    .gallery { display: flex; flex-wrap: wrap; gap: 15px; justify-content: center; }
    .gallery-item { width: 300px; text-align: center; }
    .gallery-item img { width: 100%; border: 2px solid #ddd; border-radius: 5px; cursor: pointer; }
    .gallery-item button, .zoom-tools button { font-size: 12px; padding: 2px 8px; background: #e0e0e0; color: #222; border: none; border-radius: 3px; cursor: pointer; }
    .close { position: absolute; top: 20px; right: 30px; font-size: 30px; color: white; cursor: pointer; z-index: 30; }
    .modal { display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.8); justify-content: center; align-items: center; flex-direction: column; z-index: 10; }
    .modal-content, .image-wrapper { width: 100%; height: 100%; display: flex; justify-content: center; align-items: center; flex-direction: column; }
    .image-wrapper { overflow: hidden; position: relative; cursor: grab; }
    .image-wrapper img { position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%) scale(1); transform-origin: center; user-select: none; max-width: none; max-height: none; }
    .zoom-slider-container { position: fixed; bottom: 0; left: 50%; transform: translateX(-50%); background: rgba(0, 0, 0, 0.5); padding: 8px 12px; border-radius: 10px 10px 0 0; color: white; font-size: 14px; opacity: 0; pointer-events: none; transition: opacity 0.3s; z-index: 20; }
    .modal:hover .zoom-slider-container { opacity: 1; pointer-events: auto; }
    .zoom-content { display: flex; align-items: center; gap: 12px; }
    .zoom-tools { display: flex; align-items: center; gap: 8px; }
    input[type='range'] { width: 300px; }
</style>
</head>
<body>
<h1>Resultados de BET - Revisión de Recorte</h1>
<p class='instructions'>
    Haz clic en cada imagen para verla completa.<br>
    Luego, indica el número del paciente y el umbral deseado (entre 0 y 1) para aplicar el recorte.<br>
    Ejemplo: <code>5 0.45</code>, <code>12 0.60</code>
</p>
<div class='gallery'>"
    } >> "$ruta_html"

    # Cargar los umbrales personalizados previos, si existen
    declare -A umbrales_personalizados
    seleccion_txt="$logs_dir/seleccion.txt"
    if [ -f "$seleccion_txt" ]; then
        while IFS= read -r linea; do
            archivo_salida=$(echo "$linea" | awk '{print $3}')
            umbral=$(echo "$linea" | awk -F'-f ' '{print $2}' | xargs)
            nombre_base=$(basename "${archivo_salida}.nii.gz" .nii.gz)
            umbrales_personalizados["$nombre_base"]="$umbral*"
        done < "$seleccion_txt"
    fi

    # Detectar si se ejecuta en WSL (Windows Subsystem for Linux)
    es_wsl=false
    if grep -qi microsoft /proc/version; then
        es_wsl=true
    fi

    # Recorrer las imágenes generadas por BET
    for img in "$ruta_directorio_bids/derivatives/png_converted"/*_brain.png; do
        nombre_png=$(basename "$img" .png)
        nombre_old="${nombre_png}_old"
        ruta_old="$ruta_directorio_bids/derivatives/png_converted/${nombre_old}.png"
        umbral="${umbrales_personalizados[$nombre_png]:-0.5}"
        etiqueta="$nombre_png (-f $umbral)"

        # Generar entrada HTML por cada imagen, considerando si hay versión "antes"
        if $es_wsl; then
            img_win=$(wslpath -w "$img")
            if [ -f "$ruta_old" ]; then
                img_old_win=$(wslpath -w "$ruta_old")
                cat >> "$ruta_html" <<EOF
<div class='gallery-item'>
    <label><strong>$etiqueta</strong></label><br>
    <img src='$img_old_win' id='img-${nombre_png}-before' style='display:none;' onclick="openModal(this.src)">
    <img src='$img_win' id='img-${nombre_png}-after' onclick="openModal(this.src)">
    <button onclick="toggleImage('${nombre_png}', 'before')">Antes</button>
    <button onclick="toggleImage('${nombre_png}', 'after')">Después</button>
</div>
EOF
            else
                cat >> "$ruta_html" <<EOF
<div class='gallery-item'>
    <label><strong>$etiqueta</strong></label><br>
    <img src='$img_win' id='img-${nombre_png}-only' onclick="openModal(this.src)">
</div>
EOF
            fi
        else
            if [ -f "$ruta_old" ]; then
                cat >> "$ruta_html" <<EOF
<div class='gallery-item'>
    <label><strong>$etiqueta</strong></label><br>
    <img src='$ruta_old' id='img-${nombre_png}-before' style='display:none;' onclick="openModal(this.src)">
    <img src='$img' id='img-${nombre_png}-after' onclick="openModal(this.src)">
    <button onclick="toggleImage('${nombre_png}', 'before')">Antes</button>
    <button onclick="toggleImage('${nombre_png}', 'after')">Después</button>
</div>
EOF
            else
                cat >> "$ruta_html" <<EOF
<div class='gallery-item'>
    <label><strong>$etiqueta</strong></label><br>
    <img src='$img' id='img-${nombre_png}-only' onclick="openModal(this.src)">
</div>
EOF
            fi
        fi
    done

    # Añadir sección de modal para ver las imágenes en grande y controlar zoom
    cat >> "$ruta_html" <<'EOF'
</div>
<div class='modal' id='imageModal'>
    <span class='close' onclick='closeModal()'>&times;</span>
    <div class='modal-content'>
        <div class='image-wrapper' id='imageWrapper'>
            <img id='modalImage' src=''>
        </div>
    </div>
    <div class="zoom-slider-container" id="zoomControls">
        <div class="zoom-content">
            <div class="zoom-tools">
                <label for="zoomSlider">Zoom:</label>
                <input type="range" id="zoomSlider" min="0.5" max="5" step="0.1" value="1">
                <button onclick="resetView()">↺ Reiniciar vista</button>
            </div>
        </div>
    </div>
</div>
<div class='footer'>Generado automáticamente por el Pipeline task-fMRI.</div>
<script>
    // JavaScript: funciones para abrir el modal, hacer zoom, mover la imagen, etc.
    const modal = document.getElementById('imageModal');
    const modalImg = document.getElementById('modalImage');
    const zoomSlider = document.getElementById('zoomSlider');
    const wrapper = document.getElementById('imageWrapper');
    let scale = 1, offsetX = 0, offsetY = 0;
    let isDragging = false, dragStartX = 0, dragStartY = 0;

    function openModal(src) {
        modal.style.display = 'flex';
        modalImg.src = src;
        modalImg.onload = () => { scale = 1; offsetX = 0; offsetY = 0; zoomSlider.value = scale; updateTransform(); };
    }

    function closeModal() { modal.style.display = 'none'; }

    zoomSlider.addEventListener('input', () => {
        const prev = scale;
        scale = parseFloat(zoomSlider.value);
        offsetX *= scale / prev; offsetY *= scale / prev;
        updateTransform();
    });

    wrapper.addEventListener('mousedown', e => { isDragging = true; dragStartX = e.clientX - offsetX; dragStartY = e.clientY - offsetY; });
    document.addEventListener('mousemove', e => { if (!isDragging) return; offsetX = e.clientX - dragStartX; offsetY = e.clientY - dragStartY; updateTransform(); });
    document.addEventListener('mouseup', () => isDragging = false);

    wrapper.addEventListener('wheel', e => {
        if (e.ctrlKey) {
            e.preventDefault();
            const delta = e.deltaY > 0 ? -0.1 : 0.1;
            const prev = scale;
            scale = Math.min(5, Math.max(0.5, scale + delta));
            offsetX *= scale / prev; offsetY *= scale / prev;
            zoomSlider.value = scale.toFixed(1);
        } else {
            offsetX -= e.deltaX;
            offsetY -= e.deltaY;
        }
        updateTransform();
    }, { passive: false });

    document.addEventListener('keydown', e => {
        const step = 30;
        if (e.key === 'Escape') closeModal();
        if (e.key === 'ArrowUp') offsetY += step;
        if (e.key === 'ArrowDown') offsetY -= step;
        if (e.key === 'ArrowLeft') offsetX += step;
        if (e.key === 'ArrowRight') offsetX -= step;
        updateTransform();
    });

    function updateTransform() {
        modalImg.style.transform = `translate(-50%, -50%) translate(${offsetX}px, ${offsetY}px) scale(${scale})`;
    }

    function resetView() {
        scale = 1; offsetX = 0; offsetY = 0;
        zoomSlider.value = scale;
        updateTransform();
    }

    function toggleImage(id, version) {
        const before = document.getElementById('img-' + id + '-before');
        const after = document.getElementById('img-' + id + '-after');
        if (before && after) {
            if (version === 'before') {
                before.style.display = 'block';
                after.style.display = 'none';
            } else {
                before.style.display = 'none';
                after.style.display = 'block';
            }
        }
    }
</script>
</body>
</html>
EOF

    # Imprime ruta al archivo generado
    echo -e "${COLOR_EXITO}HTML generado en: $ruta_html${COLOR_NORMAL}"

    # Abre el HTML automáticamente en navegador
    if grep -qi microsoft /proc/version; then
        ruta_windows=$(wslpath -w "$ruta_html")
        if command -v "/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" &>/dev/null; then
            "/mnt/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" "$ruta_windows" &
        elif command -v "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe" &>/dev/null; then
            "/mnt/c/Program Files/Google/Chrome/Application/chrome.exe" "$ruta_windows" &
        fi
    else
        command -v xdg-open &>/dev/null && xdg-open "$ruta_html" &
    fi
}


# ponet set ..... bet en 0 para que no se aplique el bet por defecto.


###### fslval ruta dim4         #numero de volúmenes
###### fslval ruta pixdim4         #Tiempo de repetición 


generar_archivo_design(){
    echo "${COLOR_MODULO}\nGenerando archivo de diseño para FSL.\n${COLOR_NORMAL}"
}