-- ============================================================
--  SISTEMA "HUELLAS SEGURAS" — Package PL/SQL
--  PKG_PROTECTORA: Especificación + Cuerpo
--  Base de datos: Oracle Database 12c o superior
-- ============================================================


-- ------------------------------------------------------------
-- ESPECIFICACIÓN DEL PACKAGE
-- (Interfaz pública: lo que otros programas pueden llamar)
-- ------------------------------------------------------------

CREATE OR REPLACE PACKAGE PKG_PROTECTORA AS

    -- ----------------------------------------------------------
    -- CONSTANTES de estado (evitan cadenas literales dispersas)
    -- ----------------------------------------------------------
    C_ESTADO_DISPONIBLE   CONSTANT VARCHAR2(20) := 'Disponible';
    C_ESTADO_TRATAMIENTO  CONSTANT VARCHAR2(20) := 'En tratamiento';
    C_ESTADO_ADOPTADO     CONSTANT VARCHAR2(20) := 'Adoptado';

    -- ----------------------------------------------------------
    -- FUNCIÓN: FN_APTO_ADOPCION
    --   Parámetros:
    --     p_id_animal  NUMBER  — ID del animal a verificar
    --   Devuelve:
    --     BOOLEAN — TRUE si el animal está en estado 'Disponible'
    --               FALSE en cualquier otro caso
    --   Uso previo al proceso de adopción para validar disponibilidad.
    -- ----------------------------------------------------------
    FUNCTION FN_APTO_ADOPCION (
        p_id_animal IN ANIMALES.ID_ANIMAL%TYPE
    ) RETURN BOOLEAN;


    -- ----------------------------------------------------------
    -- PROCEDIMIENTO: SP_ADOPTAR_ANIMAL
    --   Registra una adopción en una única transacción atómica:
    --     1. Verifica que el animal existe y está disponible.
    --     2. Inserta el registro en ADOPCIONES.
    --     3. Actualiza el estado del animal a 'Adoptado'.
    --     4. COMMIT si todo va bien / ROLLBACK si hay error.
    --
    --   Parámetros:
    --     p_id_animal     NUMBER        — ID del animal a adoptar
    --     p_id_adoptante  NUMBER        — ID del adoptante
    --     p_observaciones VARCHAR2(500) — Notas opcionales
    --     p_resultado     OUT VARCHAR2  — Mensaje de resultado
    --                                    ('OK' o descripción del error)
    -- ----------------------------------------------------------
    PROCEDURE SP_ADOPTAR_ANIMAL (
        p_id_animal     IN  ANIMALES.ID_ANIMAL%TYPE,
        p_id_adoptante  IN  ADOPTANTES.ID_ADOPTANTE%TYPE,
        p_observaciones IN  ADOPCIONES.OBSERVACIONES%TYPE DEFAULT NULL,
        p_resultado     OUT VARCHAR2
    );


    -- ----------------------------------------------------------
    -- PROCEDIMIENTO: SP_CAMBIAR_ESTADO
    --   Cambia el estado de un animal con validación.
    --   El trigger TRG_AUDIT_ESTADO_ANIMAL registra el cambio
    --   automáticamente en AUDIT_ANIMALES.
    --
    --   Parámetros:
    --     p_id_animal  NUMBER       — ID del animal
    --     p_nuevo_estado VARCHAR2   — Nuevo estado a asignar
    --     p_resultado  OUT VARCHAR2 — 'OK' o mensaje de error
    -- ----------------------------------------------------------
    PROCEDURE SP_CAMBIAR_ESTADO (
        p_id_animal    IN  ANIMALES.ID_ANIMAL%TYPE,
        p_nuevo_estado IN  ANIMALES.ESTADO%TYPE,
        p_resultado    OUT VARCHAR2
    );


    -- ----------------------------------------------------------
    -- FUNCIÓN: FN_CONTAR_POR_ESPECIE
    --   Devuelve el número de animales de una especie concreta
    --   con un estado determinado (o todos si estado es NULL).
    --
    --   Parámetros:
    --     p_especie  VARCHAR2 — Especie a consultar
    --     p_estado   VARCHAR2 — Estado a filtrar (NULL = todos)
    --   Devuelve:
    --     NUMBER — Número de animales que cumplen el criterio
    -- ----------------------------------------------------------
    FUNCTION FN_CONTAR_POR_ESPECIE (
        p_especie IN ANIMALES.ESPECIE%TYPE,
        p_estado  IN ANIMALES.ESTADO%TYPE DEFAULT NULL
    ) RETURN NUMBER;

END PKG_PROTECTORA;
/


-- ------------------------------------------------------------
-- CUERPO DEL PACKAGE
-- (Implementación de toda la lógica)
-- ------------------------------------------------------------

CREATE OR REPLACE PACKAGE BODY PKG_PROTECTORA AS

    -- ==========================================================
    -- FUNCIÓN PRIVADA: obtiene el estado actual de un animal.
    -- Solo visible dentro del package (no declarada en la spec).
    -- ==========================================================
    FUNCTION fn_obtener_estado (
        p_id_animal IN ANIMALES.ID_ANIMAL%TYPE
    ) RETURN VARCHAR2 IS
        v_estado ANIMALES.ESTADO%TYPE;
    BEGIN
        SELECT ESTADO
        INTO   v_estado
        FROM   ANIMALES
        WHERE  ID_ANIMAL = p_id_animal;

        RETURN v_estado;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL;  -- El animal no existe
    END fn_obtener_estado;


    -- ==========================================================
    -- FUNCIÓN PÚBLICA: FN_APTO_ADOPCION
    -- ==========================================================
    FUNCTION FN_APTO_ADOPCION (
        p_id_animal IN ANIMALES.ID_ANIMAL%TYPE
    ) RETURN BOOLEAN IS
        v_estado ANIMALES.ESTADO%TYPE;
    BEGIN
        v_estado := fn_obtener_estado(p_id_animal);

        -- Si no existe el animal, no está apto
        IF v_estado IS NULL THEN
            RETURN FALSE;
        END IF;

        -- Solo está apto si su estado es 'Disponible'
        RETURN (v_estado = C_ESTADO_DISPONIBLE);

    END FN_APTO_ADOPCION;


    -- ==========================================================
    -- PROCEDIMIENTO PÚBLICO: SP_ADOPTAR_ANIMAL
    -- ==========================================================
    PROCEDURE SP_ADOPTAR_ANIMAL (
        p_id_animal     IN  ANIMALES.ID_ANIMAL%TYPE,
        p_id_adoptante  IN  ADOPTANTES.ID_ADOPTANTE%TYPE,
        p_observaciones IN  ADOPCIONES.OBSERVACIONES%TYPE DEFAULT NULL,
        p_resultado     OUT VARCHAR2
    ) IS
        v_existe_adoptante NUMBER;

    BEGIN
        -- -------------------------------------------------------
        -- VALIDACIÓN 1: Verificar que el animal es apto
        -- -------------------------------------------------------
        IF NOT FN_APTO_ADOPCION(p_id_animal) THEN
            -- Distinguir entre "no existe" y "no disponible"
            IF fn_obtener_estado(p_id_animal) IS NULL THEN
                p_resultado := 'ERROR: El animal con ID ' || p_id_animal ||
                               ' no existe en la base de datos.';
            ELSE
                p_resultado := 'ERROR: El animal con ID ' || p_id_animal ||
                               ' no está disponible para adopción. Estado actual: ' ||
                               fn_obtener_estado(p_id_animal);
            END IF;
            RETURN;  -- Salir sin hacer nada más
        END IF;

        -- -------------------------------------------------------
        -- VALIDACIÓN 2: Verificar que el adoptante existe
        -- -------------------------------------------------------
        SELECT COUNT(*)
        INTO   v_existe_adoptante
        FROM   ADOPTANTES
        WHERE  ID_ADOPTANTE = p_id_adoptante;

        IF v_existe_adoptante = 0 THEN
            p_resultado := 'ERROR: El adoptante con ID ' || p_id_adoptante ||
                           ' no existe en la base de datos.';
            RETURN;
        END IF;

        -- -------------------------------------------------------
        -- OPERACIÓN ATÓMICA: Insertar adopción + Cambiar estado
        -- -------------------------------------------------------

        -- Paso 1: Insertar registro de adopción
        INSERT INTO ADOPCIONES (
            ID_ANIMAL,
            ID_ADOPTANTE,
            FECHA,
            OBSERVACIONES
        ) VALUES (
            p_id_animal,
            p_id_adoptante,
            SYSDATE,
            p_observaciones
        );

        -- Paso 2: Actualizar estado del animal a 'Adoptado'
        -- (Este UPDATE dispara TRG_AUDIT_ESTADO_ANIMAL automáticamente)
        UPDATE ANIMALES
        SET    ESTADO = C_ESTADO_ADOPTADO
        WHERE  ID_ANIMAL = p_id_animal;

        -- Confirmar la transacción completa
        COMMIT;

        p_resultado := 'OK: Adopción registrada correctamente. ' ||
                       'El animal ID ' || p_id_animal ||
                       ' ha sido adoptado por el adoptante ID ' || p_id_adoptante || '.';

    EXCEPTION
        WHEN OTHERS THEN
            -- Revertir cualquier cambio parcial ante error inesperado
            ROLLBACK;
            p_resultado := 'ERROR INESPERADO: ' || SQLERRM;
    END SP_ADOPTAR_ANIMAL;


    -- ==========================================================
    -- PROCEDIMIENTO PÚBLICO: SP_CAMBIAR_ESTADO
    -- ==========================================================
    PROCEDURE SP_CAMBIAR_ESTADO (
        p_id_animal    IN  ANIMALES.ID_ANIMAL%TYPE,
        p_nuevo_estado IN  ANIMALES.ESTADO%TYPE,
        p_resultado    OUT VARCHAR2
    ) IS
        v_estado_actual ANIMALES.ESTADO%TYPE;
    BEGIN
        -- Verificar que el estado nuevo es válido
        IF p_nuevo_estado NOT IN (C_ESTADO_DISPONIBLE,
                                   C_ESTADO_TRATAMIENTO,
                                   C_ESTADO_ADOPTADO) THEN
            p_resultado := 'ERROR: Estado no válido: "' || p_nuevo_estado ||
                           '". Use: Disponible, En tratamiento o Adoptado.';
            RETURN;
        END IF;

        -- Obtener estado actual
        v_estado_actual := fn_obtener_estado(p_id_animal);

        IF v_estado_actual IS NULL THEN
            p_resultado := 'ERROR: No existe ningún animal con ID ' || p_id_animal;
            RETURN;
        END IF;

        -- No tiene sentido cambiar al mismo estado
        IF v_estado_actual = p_nuevo_estado THEN
            p_resultado := 'AVISO: El animal ya tiene el estado "' || p_nuevo_estado || '".';
            RETURN;
        END IF;

        -- Realizar el cambio (el trigger se encargará de la auditoría)
        UPDATE ANIMALES
        SET    ESTADO = p_nuevo_estado
        WHERE  ID_ANIMAL = p_id_animal;

        COMMIT;

        p_resultado := 'OK: Estado del animal ID ' || p_id_animal ||
                       ' cambiado de "' || v_estado_actual ||
                       '" a "' || p_nuevo_estado || '".';

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            p_resultado := 'ERROR INESPERADO: ' || SQLERRM;
    END SP_CAMBIAR_ESTADO;


    -- ==========================================================
    -- FUNCIÓN PÚBLICA: FN_CONTAR_POR_ESPECIE
    -- ==========================================================
    FUNCTION FN_CONTAR_POR_ESPECIE (
        p_especie IN ANIMALES.ESPECIE%TYPE,
        p_estado  IN ANIMALES.ESTADO%TYPE DEFAULT NULL
    ) RETURN NUMBER IS
        v_total NUMBER;
    BEGIN
        IF p_estado IS NULL THEN
            -- Contar todos los animales de la especie sin filtrar estado
            SELECT COUNT(*)
            INTO   v_total
            FROM   ANIMALES
            WHERE  UPPER(ESPECIE) = UPPER(p_especie);
        ELSE
            -- Contar filtrando también por estado
            SELECT COUNT(*)
            INTO   v_total
            FROM   ANIMALES
            WHERE  UPPER(ESPECIE) = UPPER(p_especie)
              AND  ESTADO = p_estado;
        END IF;

        RETURN v_total;

    EXCEPTION
        WHEN OTHERS THEN
            RETURN -1;  -- Indicador de error
    END FN_CONTAR_POR_ESPECIE;

END PKG_PROTECTORA;
/


-- ============================================================
-- VERIFICACIÓN: Mostrar posibles errores de compilación
-- ============================================================
SHOW ERRORS PACKAGE PKG_PROTECTORA;
SHOW ERRORS PACKAGE BODY PKG_PROTECTORA;


-- ============================================================
-- EJEMPLOS DE USO (comentados — ejecutar en SQL*Plus o APEX)
-- ============================================================

/*
-- Ejemplo 1: Verificar si un animal es apto para adopción
DECLARE
    v_apto BOOLEAN;
BEGIN
    v_apto := PKG_PROTECTORA.FN_APTO_ADOPCION(1);
    IF v_apto THEN
        DBMS_OUTPUT.PUT_LINE('El animal 1 ESTÁ disponible para adopción.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('El animal 1 NO está disponible para adopción.');
    END IF;
END;
/

-- Ejemplo 2: Realizar una adopción
DECLARE
    v_resultado VARCHAR2(500);
BEGIN
    PKG_PROTECTORA.SP_ADOPTAR_ANIMAL(
        p_id_animal     => 1,
        p_id_adoptante  => 1,
        p_observaciones => 'Familia con jardín, ideal para el animal.',
        p_resultado     => v_resultado
    );
    DBMS_OUTPUT.PUT_LINE(v_resultado);
END;
/

-- Ejemplo 3: Cambiar estado a "En tratamiento"
DECLARE
    v_resultado VARCHAR2(500);
BEGIN
    PKG_PROTECTORA.SP_CAMBIAR_ESTADO(
        p_id_animal    => 4,
        p_nuevo_estado => 'En tratamiento',
        p_resultado    => v_resultado
    );
    DBMS_OUTPUT.PUT_LINE(v_resultado);
END;
/

-- Ejemplo 4: Contar perros disponibles
DECLARE
    v_total NUMBER;
BEGIN
    v_total := PKG_PROTECTORA.FN_CONTAR_POR_ESPECIE('Perro', 'Disponible');
    DBMS_OUTPUT.PUT_LINE('Perros disponibles: ' || v_total);
END;
/

-- Ejemplo 5: Consultar el log de auditoría
SELECT
    a.ID_AUDIT,
    an.NOMBRE        AS ANIMAL,
    a.ESTADO_ANTERIOR,
    a.ESTADO_NUEVO,
    TO_CHAR(a.FECHA_CAMBIO, 'DD/MM/YYYY HH24:MI:SS') AS CUANDO,
    a.USUARIO_BD
FROM AUDIT_ANIMALES a
JOIN ANIMALES an ON an.ID_ANIMAL = a.ID_ANIMAL
ORDER BY a.FECHA_CAMBIO DESC;
*/

-- ============================================================
-- FIN DEL SCRIPT PL/SQL
-- ============================================================
