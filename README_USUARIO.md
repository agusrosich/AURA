# AURA - Sistema Automático de Segmentación Radiológica

AURA es una aplicación de escritorio para segmentación automática de estructuras anatómicas en imágenes médicas CT (Tomografía Computarizada) utilizando inteligencia artificial.

## 🎯 Características Principales

- ✅ **Segmentación automática** de más de 100 estructuras anatómicas
- ✅ **Fusión inteligente** de órganos (ej: lóbulos pulmonares → pulmones completos)
- ✅ **Exportación DICOM RT-STRUCT** compatible con sistemas PACS
- ✅ **Procesamiento por lotes** de múltiples pacientes
- ✅ **Soporte GPU** para procesamiento acelerado (opcional)
- ✅ **Interfaz gráfica** intuitiva en español

## 💻 Requisitos del Sistema

### Mínimo
- Windows 10/11 (64-bit)
- Procesador Intel/AMD de 4 núcleos o superior
- 8 GB de RAM
- 10 GB de espacio libre en disco
- Conexión a Internet (para descarga inicial de modelos)

### Recomendado
- Windows 11 (64-bit)
- Procesador Intel/AMD de 8 núcleos o superior
- 16 GB de RAM o más
- 20 GB de espacio libre en disco
- GPU NVIDIA con 6+ GB VRAM (opcional, para aceleración)
- SSD para almacenamiento

## 📦 Instalación

### Paso 1: Extraer archivos
Extrae todos los archivos del ZIP a una carpeta temporal.

### Paso 2: Ejecutar instalador
Haz doble clic en `AURA_Setup_1.0.exe`

### Paso 3: Seguir el asistente
1. **Bienvenida**: Lee la información y haz clic en "Siguiente"
2. **Directorio**: Elige dónde instalar AURA (por defecto: `C:\Program Files\AURA`)
3. **Accesos directos**: Marca la casilla si deseas un icono en el escritorio
4. **Modelos de IA**:
   - ✅ **Recomendado**: Marca "Descargar modelos automáticamente"
   - ⏱️ La descarga puede tardar 10-30 minutos (2-5 GB)
   - 🌐 Requiere conexión a Internet estable
   - ℹ️ Si no descargas ahora, AURA descargará los modelos la primera vez que lo uses
5. **Instalación**: Espera a que se copien los archivos
6. **Finalizar**: Opcionalmente, marca "Ejecutar AURA" para iniciarlo inmediatamente

### Paso 4: Primera ejecución
La primera vez que ejecutes AURA:

**IMPORTANTE: Descarga de Modelos**

Los modelos de IA (~2-5 GB) se descargan automáticamente la primera vez que procesas un paciente:

1. Abre AURA
2. Selecciona órganos y carpetas
3. Haz clic en "Procesar Uno"
4. **Verás un mensaje**: "DESCARGANDO MODELOS DE TOTALSEGMENTATOR"
5. **ESPERA**: La descarga puede tardar 10-30 minutos
6. ☕ La barra de progreso estará activa - **NO cierres la aplicación**
7. Una vez descargados, el procesamiento comenzará automáticamente

💡 **Solo la primera vez**: Los modelos se guardan en tu computadora y no necesitas descargarlos de nuevo.

🌐 **Conexión a Internet**: Necesitas conexión estable durante la primera descarga.

## 🚀 Uso Básico

### 1. Seleccionar órganos
- Haz clic en el botón **"Seleccionar Órganos"**
- Marca las estructuras que deseas segmentar
- Puedes usar los **Presets** para selecciones rápidas:
  - "Thorax (Main)": Pulmones y corazón
  - "Abdomen (Main)": Hígado, bazo, riñones, páncreas
  - "Complete Spine": Todas las vértebras

### 2. Configurar carpetas
- **Carpeta de entrada**: Carpeta que contiene los archivos DICOM del CT
- **Carpeta de salida**: Dónde se guardarán los resultados

### 3. Procesar
- **Procesar Uno**: Procesa el paciente en la carpeta de entrada
- **Procesar Todos**: Procesa todos los pacientes (cada subcarpeta = un paciente)

### 4. Resultados
AURA crea una carpeta para cada paciente con:
- 📁 `CT/`: Copias de los archivos DICOM originales
- 📄 `RTSTRUCT_*.dcm`: Archivo con las segmentaciones (importable en tu sistema PACS)

## ⚙️ Configuración Avanzada

### Menú "Opciones"

#### Preferencia de Dispositivo
- **CPU**: Usa el procesador (más lento, funciona en cualquier PC)
- **GPU**: Usa la tarjeta gráfica NVIDIA (mucho más rápido)
  - ℹ️ Requiere GPU compatible con CUDA
  - ℹ️ AURA detecta automáticamente si tienes GPU compatible

#### Resolución del Modelo
- **Alta Resolución**: Más preciso, más lento, más RAM
- **Baja Resolución** (Fast): Más rápido, menos preciso

#### Opciones de Segmentación
- **Limpiar máscaras**: Elimina pequeños artefactos
- **Suavizar contornos**: Hace los bordes más suaves
- **Recorte automático**: Optimiza el área de procesamiento

### Menú "Vista"
- **Tema**: Cambia entre tema claro, oscuro y del sistema

## 🫁 Fusión Automática de Pulmones

AURA fusiona automáticamente los lóbulos pulmonares en dos estructuras completas:
- **lung_left**: Pulmón izquierdo completo
- **lung_right**: Pulmón derecho completo

Esto facilita el trabajo con los contornos en tu sistema de planificación.

## 🐛 Solución de Problemas

### AURA no inicia
1. Verifica que tienes Windows 10/11 de 64 bits
2. Reinstala AURA
3. Revisa el archivo de log: `C:\Program Files\AURA\logs\app.log`

### Error "No se pudo cargar el modelo"
1. Verifica tu conexión a Internet
2. Cierra AURA completamente
3. Vuelve a abrir AURA (intentará descargar los modelos nuevamente)

### Procesamiento muy lento
1. En "Opciones" → "Preferencia de Dispositivo", prueba cambiar entre CPU y GPU
2. En "Opciones" → "Resolución del Modelo", selecciona "Baja Resolución (Fast)"
3. Cierra otras aplicaciones que consuman mucha RAM

### Error "Sin memoria suficiente"
1. Cierra otras aplicaciones
2. Usa "Baja Resolución (Fast)" en las opciones
3. Procesa de a un paciente a la vez

### GPU no detectada
1. Verifica que tu GPU es NVIDIA (AMD/Intel no están soportadas para aceleración)
2. Instala los drivers más recientes de NVIDIA
3. Verifica que tienes CUDA instalado

### Archivos DICOM no reconocidos
1. Asegúrate de que los archivos son CT (no MRI, PET, etc.)
2. Verifica que los archivos son DICOM válidos
3. Revisa que la carpeta contiene una serie completa (no imágenes sueltas)

## 📋 Órganos Soportados

AURA puede segmentar automáticamente:

### Tórax
- Pulmones (fusionados automáticamente)
- Corazón y estructuras cardíacas
- Esófago, tráquea
- Vasos principales

### Abdomen
- Hígado, bazo
- Riñones, glándulas suprarrenales
- Páncreas, vesícula biliar
- Estómago, intestinos

### Columna
- Todas las vértebras (C1-C7, T1-T12, L1-L5)
- Sacro

### Otros
- Huesos (costillas, fémures, pelvis, etc.)
- Músculos principales
- Vasos sanguíneos
- Y muchos más... ¡más de 100 estructuras en total!

## 📄 Formato de Salida

AURA genera archivos **DICOM RT-STRUCT** estándar, compatibles con:
- ✅ Eclipse (Varian)
- ✅ RayStation
- ✅ Monaco
- ✅ Pinnacle
- ✅ MIM
- ✅ Velocity
- ✅ Cualquier sistema que soporte DICOM RT-STRUCT

## 🔒 Privacidad y Seguridad

- ✅ **Procesamiento local**: Todas las imágenes se procesan en tu computadora
- ✅ **Sin envío de datos**: AURA nunca envía tus datos a Internet
- ✅ **Solo descarga modelos**: La única conexión a Internet es para descargar los modelos de IA (una sola vez)

## 📞 Soporte y Ayuda

### ¿Tienes preguntas?
- 📧 Email: [Agregar email de soporte]
- 🌐 Web: [Agregar URL del sitio]
- 📚 Documentación: [Agregar URL de docs]

### ¿Encontraste un error?
Por favor repórtalo incluyendo:
1. Versión de AURA (ver en "Ayuda" → "Acerca de")
2. Versión de Windows
3. Descripción del problema
4. Archivo de log (en `logs/app.log`)

## 📜 Licencia

[Agregar información de licencia]

## 🙏 Agradecimientos

AURA utiliza los siguientes proyectos de código abierto:
- **TotalSegmentator**: Modelos de segmentación
- **nnU-Net**: Framework de segmentación
- **MONAI**: Framework de imagen médica
- **PyTorch**: Framework de deep learning
- **rt-utils**: Utilidades para RT-STRUCT

---

**¡Gracias por usar AURA!**

Esperamos que esta herramienta te ayude a agilizar tu trabajo diario.
