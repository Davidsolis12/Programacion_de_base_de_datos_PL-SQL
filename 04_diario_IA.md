# Diario de IA — Sistema "Huellas Seguras"
**Asignatura:** Programación de Bases de Datos. PL/SQL
**Herramienta utilizada:** Claude (Anthropic)

---

## 1. Introducción

Este documento recoge los prompts principales utilizados durante el desarrollo del proyecto.
El uso de IA se ha empleado como herramienta de apoyo para acelerar la generación de código repetitivo y estructurar la documentación.

---

## 2. Registro de Prompts

---

### Prompt 1 — Especificación de diseño

**Prompt enviado:**
> "Genera la especificación de diseño en formato Markdown para un sistema de gestión de protectora de animales llamado 'Huellas Seguras'. Debe incluir diccionario de datos para las tablas ANIMALES, ADOPTANTES, ADOPCIONES, HISTORIAL_MEDICO y una tabla de auditoría. Incluye también la lógica de negocio y un mapa de navegación para Oracle APEX."


**Correcciones y decisiones propias:**

- La IA inicialmente propuso usar el tipo `VARCHAR` en algunas columnas. Se corrigió a `VARCHAR2`, que es el tipo correcto en Oracle. `VARCHAR` está reservado para uso futuro en Oracle y su comportamiento puede ser impredecible.
- Se añadió manualmente la columna `USUARIO_BD` en `AUDIT_ANIMALES` usando la función `USER` de Oracle, que la IA no había incluido en la primera versión.
- El mapa de navegación de APEX fue ampliado para incluir la página de auditoría (página 7), que la IA había omitido.

---

### Prompt 2 — Scripts DDL

**Prompt enviado:**
> "Genera el script DDL completo para Oracle Database con las tablas ANIMALES, ADOPTANTES, ADOPCIONES, HISTORIAL_MEDICO y AUDIT_ANIMALES. Usa secuencias para las claves primarias, triggers BEFORE INSERT para el autoincremento, constraints nombrados explícitamente (PK, FK, CHECK, UNIQUE) y un trigger de auditoría AFTER UPDATE sobre el campo ESTADO de ANIMALES."

**Correcciones y decisiones propias:**

- La IA usó `VARCHAR` en varios campos. Corregido a `VARCHAR2` en todos los casos.
- El trigger de auditoría generado por la IA no incluía la condición `IF :OLD.ESTADO <> :NEW.ESTADO THEN`, lo que habría provocado inserciones en el log incluso cuando el estado no cambiaba (por ejemplo, en un UPDATE de otro campo). Se añadió esta comprobación manualmente.
- La IA no había nombrado explícitamente todos los constraints. Se revisó y se nombraron todos siguiendo la convención `PK_`, `FK_`, `UQ_`, `CK_` para facilitar el mantenimiento.
- Se añadió un bloque de limpieza previa comentado (`DROP TABLE ... CASCADE CONSTRAINTS`) que la IA no incluyó y que es muy útil durante el desarrollo para reiniciar el esquema.
- Los datos de prueba fueron revisados para garantizar coherencia: el animal con ID 2 (Misu) tiene estado `'En tratamiento'`, lo que permite probar el rechazo de adopción en ese caso.

---

### Prompt 3 — Package PL/SQL

**Prompt enviado:**
> "Crea el package PKG_PROTECTORA en Oracle PL/SQL con: una función FN_APTO_ADOPCION que devuelva BOOLEAN según el estado del animal, un procedimiento SP_ADOPTAR_ANIMAL que realice la adopción en una transacción atómica con COMMIT y ROLLBACK, un procedimiento SP_CAMBIAR_ESTADO y una función FN_CONTAR_POR_ESPECIE. Incluye la especificación y el cuerpo por separado."


**Correcciones y decisiones propias:**

- La IA declaró la función auxiliar `fn_obtener_estado` en la especificación pública del package. Se movió al cuerpo como función privada, ya que es un detalle de implementación que no debe exponerse al exterior. Esto es una buena práctica de encapsulación en PL/SQL.
- El procedimiento `SP_ADOPTAR_ANIMAL` generado por la IA no distinguía entre "animal inexistente" y "animal no disponible" en el mensaje de error. Se mejoró para dar un mensaje diferente en cada caso, lo que facilita la depuración.
- La IA no incluyó constantes para los literales de estado (`'Disponible'`, `'En tratamiento'`, `'Adoptado'`). Se añadieron como constantes `C_ESTADO_*` al inicio de la especificación para evitar errores tipográficos y centralizar los valores posibles.
- En `FN_CONTAR_POR_ESPECIE`, la IA no había aplicado `UPPER()` para la comparación de especie, lo que hubiera causado que `'perro'` y `'Perro'` dieran resultados distintos. Se corrigió con `UPPER(ESPECIE) = UPPER(p_especie)`.
- Se añadió `SHOW ERRORS` al final del script, que la IA no incluyó, para facilitar la detección de errores de compilación en SQL*Plus.

---

## 3. Reflexión General


### Errores recurrentes de la IA en Oracle
| Error de la IA | Corrección aplicada |
|---|---|
| Uso de `VARCHAR` en lugar de `VARCHAR2` | Cambiado a `VARCHAR2` en todos los campos de texto |
| Trigger de auditoría sin condición de cambio real | Añadido `IF :OLD.ESTADO <> :NEW.ESTADO THEN` |
| Función privada expuesta en la especificación pública | Movida al cuerpo del package |
| Comparaciones de texto sin `UPPER()` | Añadido `UPPER()` para insensibilidad a mayúsculas |
| Falta de `SHOW ERRORS` tras compilación | Añadido al final del script |

### Conclusión
La IA es una herramienta útil para generar código base, pero no reemplaza el conocimiento del entorno específico. En Oracle, detalles como `VARCHAR2` vs `VARCHAR`, el comportamiento de los triggers o la visibilidad de los elementos de un package requieren criterio propio. Cada bloque de código fue revisado, comprendido y ajustado antes de incluirse en la entrega.

---
