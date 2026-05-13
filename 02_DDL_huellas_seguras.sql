-- ============================================================
--  SISTEMA "HUELLAS SEGURAS" — Protectora de Animales
--  DDL Completo: Tablas, Secuencias, Constraints, Triggers
--  Base de datos: Oracle Database 12c o superior
-- ============================================================

-- ------------------------------------------------------------
-- 0. LIMPIEZA PREVIA (ejecutar solo si se quiere reiniciar)
-- ------------------------------------------------------------
/*
DROP TABLE AUDIT_ANIMALES    CASCADE CONSTRAINTS;
DROP TABLE HISTORIAL_MEDICO  CASCADE CONSTRAINTS;
DROP TABLE ADOPCIONES        CASCADE CONSTRAINTS;
DROP TABLE ADOPTANTES        CASCADE CONSTRAINTS;
DROP TABLE ANIMALES          CASCADE CONSTRAINTS;

DROP SEQUENCE SEQ_ANIMALES;
DROP SEQUENCE SEQ_ADOPTANTES;
DROP SEQUENCE SEQ_ADOPCIONES;
DROP SEQUENCE SEQ_HISTORIAL;
DROP SEQUENCE SEQ_AUDIT;
*/

-- ------------------------------------------------------------
-- 1. SECUENCIAS
-- ------------------------------------------------------------

CREATE SEQUENCE SEQ_ANIMALES
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

CREATE SEQUENCE SEQ_ADOPTANTES
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

CREATE SEQUENCE SEQ_ADOPCIONES
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

CREATE SEQUENCE SEQ_HISTORIAL
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

CREATE SEQUENCE SEQ_AUDIT
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

-- ------------------------------------------------------------
-- 2. TABLAS
-- ------------------------------------------------------------

-- 2.1 ANIMALES
CREATE TABLE ANIMALES (
    ID_ANIMAL     NUMBER          NOT NULL,
    NOMBRE        VARCHAR2(100)   NOT NULL,
    ESPECIE       VARCHAR2(50)    NOT NULL,
    RAZA          VARCHAR2(100),
    FECHA_ENTRADA DATE            DEFAULT SYSDATE NOT NULL,
    ESTADO        VARCHAR2(20)    DEFAULT 'Disponible' NOT NULL,
    -- Constraints
    CONSTRAINT PK_ANIMALES
        PRIMARY KEY (ID_ANIMAL),
    CONSTRAINT CK_ANIMALES_ESTADO
        CHECK (ESTADO IN ('Disponible', 'En tratamiento', 'Adoptado'))
);

COMMENT ON TABLE  ANIMALES              IS 'Registro de animales acogidos en la protectora';
COMMENT ON COLUMN ANIMALES.ID_ANIMAL    IS 'Clave primaria generada por SEQ_ANIMALES';
COMMENT ON COLUMN ANIMALES.ESTADO       IS 'Disponible | En tratamiento | Adoptado';

-- 2.2 ADOPTANTES
CREATE TABLE ADOPTANTES (
    ID_ADOPTANTE  NUMBER          NOT NULL,
    NOMBRE        VARCHAR2(150)   NOT NULL,
    DNI           VARCHAR2(20)    NOT NULL,
    EMAIL         VARCHAR2(200)   NOT NULL,
    TELEFONO      VARCHAR2(20),
    -- Constraints
    CONSTRAINT PK_ADOPTANTES
        PRIMARY KEY (ID_ADOPTANTE),
    CONSTRAINT UQ_ADOPTANTES_DNI
        UNIQUE (DNI),
    CONSTRAINT UQ_ADOPTANTES_EMAIL
        UNIQUE (EMAIL)
);

COMMENT ON TABLE  ADOPTANTES             IS 'Personas registradas como posibles adoptantes';
COMMENT ON COLUMN ADOPTANTES.DNI         IS 'Documento de identidad, debe ser único';

-- 2.3 ADOPCIONES
CREATE TABLE ADOPCIONES (
    ID_ADOPCION   NUMBER          NOT NULL,
    ID_ANIMAL     NUMBER          NOT NULL,
    ID_ADOPTANTE  NUMBER          NOT NULL,
    FECHA         DATE            DEFAULT SYSDATE NOT NULL,
    OBSERVACIONES VARCHAR2(500),
    -- Constraints
    CONSTRAINT PK_ADOPCIONES
        PRIMARY KEY (ID_ADOPCION),
    CONSTRAINT FK_ADOPCION_ANIMAL
        FOREIGN KEY (ID_ANIMAL)
        REFERENCES ANIMALES (ID_ANIMAL),
    CONSTRAINT FK_ADOPCION_ADOPTANTE
        FOREIGN KEY (ID_ADOPTANTE)
        REFERENCES ADOPTANTES (ID_ADOPTANTE)
);

COMMENT ON TABLE  ADOPCIONES              IS 'Registro de adopciones formalizadas';
COMMENT ON COLUMN ADOPCIONES.ID_ANIMAL    IS 'FK a ANIMALES; el animal queda en estado Adoptado';

-- 2.4 HISTORIAL_MEDICO
CREATE TABLE HISTORIAL_MEDICO (
    ID_HISTORIAL  NUMBER           NOT NULL,
    ID_ANIMAL     NUMBER           NOT NULL,
    FECHA         DATE             DEFAULT SYSDATE NOT NULL,
    DESCRIPCION   VARCHAR2(1000)   NOT NULL,
    COSTE         NUMBER(10, 2)    DEFAULT 0,
    -- Constraints
    CONSTRAINT PK_HISTORIAL
        PRIMARY KEY (ID_HISTORIAL),
    CONSTRAINT FK_HISTORIAL_ANIMAL
        FOREIGN KEY (ID_ANIMAL)
        REFERENCES ANIMALES (ID_ANIMAL),
    CONSTRAINT CK_HISTORIAL_COSTE
        CHECK (COSTE >= 0)
);

COMMENT ON TABLE  HISTORIAL_MEDICO           IS 'Tratamientos y consultas veterinarias de cada animal';
COMMENT ON COLUMN HISTORIAL_MEDICO.COSTE     IS 'Coste en euros del tratamiento; nunca negativo';

-- 2.5 AUDIT_ANIMALES
CREATE TABLE AUDIT_ANIMALES (
    ID_AUDIT        NUMBER          NOT NULL,
    ID_ANIMAL       NUMBER          NOT NULL,
    ESTADO_ANTERIOR VARCHAR2(20),
    ESTADO_NUEVO    VARCHAR2(20)    NOT NULL,
    FECHA_CAMBIO    DATE            NOT NULL,
    USUARIO_BD      VARCHAR2(100)   NOT NULL,
    -- Constraints
    CONSTRAINT PK_AUDIT
        PRIMARY KEY (ID_AUDIT)
);

COMMENT ON TABLE  AUDIT_ANIMALES               IS 'Log automático de cambios de estado de animales';
COMMENT ON COLUMN AUDIT_ANIMALES.USUARIO_BD    IS 'Usuario Oracle que ejecutó el cambio (función USER)';

-- ------------------------------------------------------------
-- 3. TRIGGERS DE CLAVE PRIMARIA (autoincremento con secuencias)
--    Compatibles con Oracle 11g y 12c+
-- ------------------------------------------------------------

CREATE OR REPLACE TRIGGER TRG_BI_ANIMALES
    BEFORE INSERT ON ANIMALES
    FOR EACH ROW
BEGIN
    IF :NEW.ID_ANIMAL IS NULL THEN
        :NEW.ID_ANIMAL := SEQ_ANIMALES.NEXTVAL;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_BI_ADOPTANTES
    BEFORE INSERT ON ADOPTANTES
    FOR EACH ROW
BEGIN
    IF :NEW.ID_ADOPTANTE IS NULL THEN
        :NEW.ID_ADOPTANTE := SEQ_ADOPTANTES.NEXTVAL;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_BI_ADOPCIONES
    BEFORE INSERT ON ADOPCIONES
    FOR EACH ROW
BEGIN
    IF :NEW.ID_ADOPCION IS NULL THEN
        :NEW.ID_ADOPCION := SEQ_ADOPCIONES.NEXTVAL;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_BI_HISTORIAL
    BEFORE INSERT ON HISTORIAL_MEDICO
    FOR EACH ROW
BEGIN
    IF :NEW.ID_HISTORIAL IS NULL THEN
        :NEW.ID_HISTORIAL := SEQ_HISTORIAL.NEXTVAL;
    END IF;
END;
/

CREATE OR REPLACE TRIGGER TRG_BI_AUDIT
    BEFORE INSERT ON AUDIT_ANIMALES
    FOR EACH ROW
BEGIN
    IF :NEW.ID_AUDIT IS NULL THEN
        :NEW.ID_AUDIT := SEQ_AUDIT.NEXTVAL;
    END IF;
END;
/

-- ------------------------------------------------------------
-- 4. TRIGGER DE AUDITORÍA — Cambios de estado de animales
-- ------------------------------------------------------------

CREATE OR REPLACE TRIGGER TRG_AUDIT_ESTADO_ANIMAL
    AFTER UPDATE OF ESTADO ON ANIMALES
    FOR EACH ROW
BEGIN
    -- Solo registrar si el estado realmente cambió
    IF :OLD.ESTADO <> :NEW.ESTADO THEN
        INSERT INTO AUDIT_ANIMALES (
            ID_ANIMAL,
            ESTADO_ANTERIOR,
            ESTADO_NUEVO,
            FECHA_CAMBIO,
            USUARIO_BD
        ) VALUES (
            :OLD.ID_ANIMAL,
            :OLD.ESTADO,
            :NEW.ESTADO,
            SYSDATE,
            USER
        );
    END IF;
END;
/

-- ------------------------------------------------------------
-- 5. DATOS DE PRUEBA
-- ------------------------------------------------------------

-- Animales
INSERT INTO ANIMALES (NOMBRE, ESPECIE, RAZA, FECHA_ENTRADA, ESTADO)
VALUES ('Canela',   'Perro', 'Labrador',        DATE '2024-01-15', 'Disponible');

INSERT INTO ANIMALES (NOMBRE, ESPECIE, RAZA, FECHA_ENTRADA, ESTADO)
VALUES ('Misu',     'Gato',  'Europeo',          DATE '2024-03-20', 'En tratamiento');

INSERT INTO ANIMALES (NOMBRE, ESPECIE, RAZA, FECHA_ENTRADA, ESTADO)
VALUES ('Rocky',    'Perro', 'Pastor Alemán',    DATE '2023-11-05', 'Disponible');

INSERT INTO ANIMALES (NOMBRE, ESPECIE, RAZA, FECHA_ENTRADA, ESTADO)
VALUES ('Luna',     'Gato',  'Siamés',           DATE '2024-05-10', 'Disponible');

INSERT INTO ANIMALES (NOMBRE, ESPECIE, RAZA, FECHA_ENTRADA, ESTADO)
VALUES ('Tobi',     'Conejo', NULL,              DATE '2024-06-01', 'Disponible');

-- Adoptantes
INSERT INTO ADOPTANTES (NOMBRE, DNI, EMAIL, TELEFONO)
VALUES ('María García López',   '12345678A', 'maria.garcia@email.com',  '600111222');

INSERT INTO ADOPTANTES (NOMBRE, DNI, EMAIL, TELEFONO)
VALUES ('Carlos Ruiz Martín',   '87654321B', 'carlos.ruiz@email.com',   '600333444');

INSERT INTO ADOPTANTES (NOMBRE, DNI, EMAIL, TELEFONO)
VALUES ('Ana Torres Vega',      '11223344C', 'ana.torres@email.com',    '600555666');

-- Historial médico
INSERT INTO HISTORIAL_MEDICO (ID_ANIMAL, FECHA, DESCRIPCION, COSTE)
VALUES (2, DATE '2024-03-22', 'Tratamiento antibiótico por infección respiratoria', 85.50);

INSERT INTO HISTORIAL_MEDICO (ID_ANIMAL, FECHA, DESCRIPCION, COSTE)
VALUES (1, DATE '2024-02-10', 'Vacunación anual y desparasitación', 45.00);

INSERT INTO HISTORIAL_MEDICO (ID_ANIMAL, FECHA, DESCRIPCION, COSTE)
VALUES (3, DATE '2024-01-18', 'Revisión general, estado óptimo', 30.00);

COMMIT;

-- ------------------------------------------------------------
-- FIN DEL SCRIPT DDL
-- ------------------------------------------------------------
