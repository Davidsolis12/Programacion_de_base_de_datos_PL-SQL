# Especificación de Diseño — Sistema "Huellas Seguras"
**Protectora de Animales | Oracle Database + Oracle APEX**
**Versión:** 1.0 | **Fecha:** Mayo 2026

---

## 1. Introducción

"Huellas Seguras" es un sistema de gestión para una protectora de animales. Permite registrar animales, adoptantes, adopciones e historial médico, centralizando toda la lógica de negocio en el servidor mediante PL/SQL.

---

## 2. Diccionario de Datos

### 2.1 Tabla: `ANIMALES`

| Columna         | Tipo          | Restricciones              | Descripción                              |
|-----------------|---------------|----------------------------|------------------------------------------|
| `ID_ANIMAL`     | NUMBER        | PK, NOT NULL               | Identificador único (secuencia)          |
| `NOMBRE`        | VARCHAR2(100) | NOT NULL                   | Nombre del animal                        |
| `ESPECIE`       | VARCHAR2(50)  | NOT NULL                   | Especie (Perro, Gato, etc.)              |
| `RAZA`          | VARCHAR2(100) | NULL                       | Raza del animal                          |
| `FECHA_ENTRADA` | DATE          | NOT NULL, DEFAULT SYSDATE  | Fecha de llegada a la protectora         |
| `ESTADO`        | VARCHAR2(20)  | NOT NULL, CHECK constraint | 'Disponible', 'En tratamiento', 'Adoptado' |

**Constraint CHECK:** `ESTADO IN ('Disponible', 'En tratamiento', 'Adoptado')`

---

### 2.2 Tabla: `ADOPTANTES`

| Columna        | Tipo          | Restricciones       | Descripción                   |
|----------------|---------------|---------------------|-------------------------------|
| `ID_ADOPTANTE` | NUMBER        | PK, NOT NULL        | Identificador único (secuencia)|
| `NOMBRE`       | VARCHAR2(150) | NOT NULL            | Nombre completo del adoptante |
| `DNI`          | VARCHAR2(20)  | NOT NULL, UNIQUE    | Documento Nacional de Identidad|
| `EMAIL`        | VARCHAR2(200) | NOT NULL, UNIQUE    | Correo electrónico            |
| `TELEFONO`     | VARCHAR2(20)  | NULL                | Número de teléfono            |

---

### 2.3 Tabla: `ADOPCIONES`

| Columna        | Tipo          | Restricciones              | Descripción                        |
|----------------|---------------|----------------------------|------------------------------------|
| `ID_ADOPCION`  | NUMBER        | PK, NOT NULL               | Identificador único (secuencia)    |
| `ID_ANIMAL`    | NUMBER        | FK → ANIMALES, NOT NULL    | Animal adoptado                    |
| `ID_ADOPTANTE` | NUMBER        | FK → ADOPTANTES, NOT NULL  | Adoptante responsable              |
| `FECHA`        | DATE          | NOT NULL, DEFAULT SYSDATE  | Fecha de la adopción               |
| `OBSERVACIONES`| VARCHAR2(500) | NULL                       | Notas adicionales sobre la adopción|

**Integridad referencial:**
- `ID_ANIMAL` → `ANIMALES(ID_ANIMAL)` — ON DELETE RESTRICT
- `ID_ADOPTANTE` → `ADOPTANTES(ID_ADOPTANTE)` — ON DELETE RESTRICT

---

### 2.4 Tabla: `HISTORIAL_MEDICO`

| Columna       | Tipo           | Restricciones           | Descripción                          |
|---------------|----------------|-------------------------|--------------------------------------|
| `ID_HISTORIAL`| NUMBER         | PK, NOT NULL            | Identificador único (secuencia)      |
| `ID_ANIMAL`   | NUMBER         | FK → ANIMALES, NOT NULL | Animal al que pertenece el registro  |
| `FECHA`       | DATE           | NOT NULL, DEFAULT SYSDATE| Fecha de la consulta/tratamiento     |
| `DESCRIPCION` | VARCHAR2(1000) | NOT NULL                | Descripción del tratamiento          |
| `COSTE`       | NUMBER(10,2)   | NULL, DEFAULT 0         | Coste económico del tratamiento      |

---

### 2.5 Tabla: `AUDIT_ANIMALES` (Auditoría)

| Columna          | Tipo          | Restricciones | Descripción                            |
|------------------|---------------|---------------|----------------------------------------|
| `ID_AUDIT`       | NUMBER        | PK, NOT NULL  | Identificador único (secuencia)        |
| `ID_ANIMAL`      | NUMBER        | NOT NULL      | Animal que cambió de estado            |
| `ESTADO_ANTERIOR`| VARCHAR2(20)  | NULL          | Estado previo al cambio                |
| `ESTADO_NUEVO`   | VARCHAR2(20)  | NOT NULL      | Nuevo estado asignado                  |
| `FECHA_CAMBIO`   | DATE          | NOT NULL      | Fecha y hora del cambio (SYSDATE)      |
| `USUARIO_BD`     | VARCHAR2(100) | NOT NULL      | Usuario de base de datos que realizó el cambio |

---

## 3. Lógica de Negocio

### 3.1 Reglas de Negocio Principales

**R1 — Aptitud para adopción:**
Un animal solo puede ser adoptado si su estado actual es `'Disponible'`. Un animal en estado `'En tratamiento'` o `'Adoptado'` no puede procesarse en una nueva adopción.

**R2 — Proceso de adopción atómico:**
Al registrar una adopción, en la misma transacción deben ocurrir dos cosas:
1. Insertar el registro en la tabla `ADOPCIONES`.
2. Actualizar el estado del animal a `'Adoptado'` en la tabla `ANIMALES`.
Si cualquiera de las dos operaciones falla, se deshace todo (`ROLLBACK`).

**R3 — Unicidad de adopción activa:**
Un animal no puede aparecer en más de una adopción una vez que su estado es `'Adoptado'`. La verificación previa (R1) lo garantiza.

**R4 — Auditoría de cambios de estado:**
Cualquier modificación en el campo `ESTADO` de la tabla `ANIMALES` debe quedar registrada automáticamente en `AUDIT_ANIMALES`, indicando quién cambió el estado, cuándo y cuál fue el valor anterior y el nuevo.

---

### 3.2 Package `PKG_PROTECTORA`

El paquete centraliza toda la lógica de negocio:

| Elemento            | Tipo      | Descripción                                                   |
|---------------------|-----------|---------------------------------------------------------------|
| `FN_APTO_ADOPCION`  | FUNCTION  | Devuelve TRUE si el animal está en estado 'Disponible'        |
| `SP_ADOPTAR_ANIMAL` | PROCEDURE | Registra la adopción y actualiza el estado en una transacción |

---

### 3.3 Trigger `TRG_AUDIT_ESTADO_ANIMAL`

Se dispara **AFTER UPDATE** sobre la columna `ESTADO` de la tabla `ANIMALES`. Por cada fila actualizada registra en `AUDIT_ANIMALES`:
- El ID del animal
- El estado anterior (`:OLD.ESTADO`)
- El estado nuevo (`:NEW.ESTADO`)
- La fecha actual (`SYSDATE`)
- El usuario de base de datos (`USER`)

---

## 4. Mapa de Navegación — Oracle APEX

```
[Página 1 — Login / Inicio]
    |
    ├── [Página 2 — Dashboard]
    │       Estadísticas: animales por especie, adopciones del mes,
    │       animales disponibles vs en tratamiento (gráfico)
    |
    ├── [Página 3 — Gestión de Animales]
    │       Informe Interactivo + Formulario CRUD
    │       Campos: Nombre, Especie, Raza, Fecha Entrada, Estado
    |
    ├── [Página 4 — Gestión de Adoptantes]
    │       Informe Interactivo + Formulario CRUD
    │       Campos: Nombre, DNI, Email, Teléfono
    |
    ├── [Página 5 — Proceso de Adopción]
    │       Formulario específico: seleccionar animal (LOV: solo Disponibles)
    │       + seleccionar adoptante + observaciones
    │       Botón "Adoptar" → invoca PKG_PROTECTORA.SP_ADOPTAR_ANIMAL
    |
    ├── [Página 6 — Historial Médico]
    │       Informe Interactivo con filtro por animal
    │       Formulario CRUD para añadir registros médicos
    |
    └── [Página 7 — Log de Auditoría]
            Informe de solo lectura de AUDIT_ANIMALES
            Filtros por fecha, animal, usuario
```

---

## 5. Secuencias

| Secuencia             | Usada en tabla   | Empieza en | Incremento |
|-----------------------|------------------|------------|------------|
| `SEQ_ANIMALES`        | ANIMALES         | 1          | 1          |
| `SEQ_ADOPTANTES`      | ADOPTANTES       | 1          | 1          |
| `SEQ_ADOPCIONES`      | ADOPCIONES       | 1          | 1          |
| `SEQ_HISTORIAL`       | HISTORIAL_MEDICO | 1          | 1          |
| `SEQ_AUDIT`           | AUDIT_ANIMALES   | 1          | 1          |

---

## 6. Consideraciones Técnicas

- Todos los tipos de texto usan `VARCHAR2` (nunca `VARCHAR`) para compatibilidad con Oracle.
- Las fechas usan tipo `DATE` de Oracle (incluye hora).
- Las claves primarias se generan con secuencias + trigger `BEFORE INSERT` (compatible con Oracle 11g/12c+).
- En Oracle 12c o superior se puede usar la cláusula `GENERATED ALWAYS AS IDENTITY`.
- Los constraints se nombran explícitamente para facilitar el mantenimiento (ej. `PK_ANIMALES`, `FK_ADOPCION_ANIMAL`).
