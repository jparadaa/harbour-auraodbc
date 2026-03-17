-- =============================================================
-- TAuraODBC Demo Database
-- SQL Server 2022 Express
-- Crear y ejecutar contra tu instancia antes de correr los tests
-- =============================================================

USE master;
GO

-- Crear base de datos si no existe
IF NOT EXISTS (
    SELECT name FROM sys.databases WHERE name = 'TAuraODBCDemo'
)
BEGIN
    CREATE DATABASE TAuraODBCDemo;
END
GO

USE TAuraODBCDemo;
GO

-- =============================================================
-- Tabla principal de pruebas
-- =============================================================
IF OBJECT_ID('dbo.productos', 'U') IS NOT NULL
    DROP TABLE dbo.productos;
GO

CREATE TABLE dbo.productos (
    id          INT IDENTITY(1,1) PRIMARY KEY,
    sku         VARCHAR(20)     NOT NULL,
    nombre      VARCHAR(100)    NOT NULL,
    categoria   VARCHAR(50)     NULL,
    precio      DECIMAL(10,2)   NOT NULL DEFAULT 0.00,
    existencia  INT             NOT NULL DEFAULT 0,
    activo      BIT             NOT NULL DEFAULT 1,
    fecha_alta  DATE            NOT NULL DEFAULT GETDATE(),
    notas       VARCHAR(255)    NULL
);
GO

-- =============================================================
-- Datos ficticios
-- =============================================================
INSERT INTO dbo.productos (sku, nombre, categoria, precio, existencia, activo, fecha_alta, notas)
VALUES
    ('ACE-5W30-1L',   'Aceite Motor 5W-30 1L',          'Aceites Motor',    89.50,  120, 1, '2025-01-10', 'API SN Plus'),
    ('ACE-10W40-4L',  'Aceite Motor 10W-40 4L',          'Aceites Motor',   310.00,   85, 1, '2025-01-10', 'API SN'),
    ('ACE-15W40-19L', 'Aceite Motor 15W-40 19L',         'Aceites Motor',  1250.00,   30, 1, '2025-01-15', 'Para diesel'),
    ('ACE-ATF-1L',    'Aceite Transmision ATF DXIII 1L', 'Aceites Trans',   145.00,   60, 1, '2025-01-20', NULL),
    ('ACE-HD-1L',     'Aceite Hidraulico AW46 1L',       'Aceites Ind',      72.00,  200, 1, '2025-02-01', NULL),
    ('FIL-ACE-001',   'Filtro de Aceite Wix 51040',      'Filtros',          85.00,  340, 1, '2025-02-05', 'Para Ford/Chevy'),
    ('FIL-ACE-002',   'Filtro de Aceite Fleetguard LF9',  'Filtros',        110.00,  180, 1, '2025-02-05', 'Para Cummins'),
    ('FIL-AIR-001',   'Filtro de Aire Wix 46506',        'Filtros',         125.00,   95, 1, '2025-02-10', NULL),
    ('FIL-COM-001',   'Filtro Combustible FS1040',       'Filtros',         165.00,  140, 1, '2025-02-10', 'Para Cummins ISB'),
    ('GRA-LIT-400G',  'Grasa Litio EP2 400g',            'Grasas',           55.00,  220, 1, '2025-03-01', NULL),
    ('GRA-MOL-400G',  'Grasa Moly Complex 400g',         'Grasas',           98.00,   75, 1, '2025-03-01', NULL),
    ('LIQ-ANT-1L',    'Anticongelante Verde 50/50 1L',   'Liquidos',         65.00,  310, 1, '2025-03-10', NULL),
    ('LIQ-FRE-1L',    'Liquido de Frenos DOT4 1L',       'Liquidos',         48.00,  190, 1, '2025-03-10', NULL),
    ('LIQ-DIR-1L',    'Liquido Direccion Hidraulica 1L', 'Liquidos',         52.00,  155, 1, '2025-03-15', NULL),
    ('DESC-001',      'Producto Descontinuado Test',     NULL,                0.00,    0, 0, '2024-12-01', 'Solo para pruebas de NULL')
;
GO

-- =============================================================
-- SP simple: busca productos por categoria con parametro
-- Usado para probar Execute() + Fetch() + FieldByName()
-- =============================================================
IF OBJECT_ID('dbo.sp_ProductosPorCategoria', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_ProductosPorCategoria;
GO

CREATE PROCEDURE dbo.sp_ProductosPorCategoria
    @Categoria  VARCHAR(50) = NULL,
    @SoloActivos BIT        = 1
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        id,
        sku,
        nombre,
        categoria,
        precio,
        existencia,
        activo,
        fecha_alta,
        notas
    FROM dbo.productos
    WHERE
        ( @Categoria IS NULL OR categoria = @Categoria )
        AND ( @SoloActivos = 0 OR activo = @SoloActivos )
    ORDER BY categoria, sku;
END
GO

-- =============================================================
-- SP con multiples resultsets: resumen ejecutivo
-- Usado para probar MoreResults()
-- Devuelve 3 resultsets:
--   1. Conteo y valor total por categoria
--   2. Top 5 productos por precio
--   3. Productos sin categoria (NULL)
-- =============================================================
IF OBJECT_ID('dbo.sp_ResumenEjecutivo', 'P') IS NOT NULL
    DROP PROCEDURE dbo.sp_ResumenEjecutivo;
GO

CREATE PROCEDURE dbo.sp_ResumenEjecutivo
    @SoloActivos BIT = 1
AS
BEGIN
    SET NOCOUNT ON;

    -- Resultset 1: conteo y valor de inventario por categoria
    SELECT
        ISNULL(categoria, '(Sin categoria)') AS categoria,
        COUNT(*)                             AS total_skus,
        SUM(existencia)                      AS total_piezas,
        CAST( SUM(precio * existencia) AS DECIMAL(12,2) ) AS valor_inventario
    FROM dbo.productos
    WHERE @SoloActivos = 0 OR activo = @SoloActivos
    GROUP BY categoria
    ORDER BY valor_inventario DESC;

    -- Resultset 2: top 5 por precio unitario
    SELECT TOP 5
        sku,
        nombre,
        precio
    FROM dbo.productos
    WHERE @SoloActivos = 0 OR activo = @SoloActivos
    ORDER BY precio DESC;

    -- Resultset 3: productos sin categoria asignada
    SELECT
        id,
        sku,
        nombre,
        activo
    FROM dbo.productos
    WHERE categoria IS NULL
    ORDER BY id;

END
GO

-- =============================================================
-- Verificacion rapida
-- =============================================================
SELECT 'Productos insertados: ' + CAST(COUNT(*) AS VARCHAR) AS info
FROM dbo.productos;
GO

SELECT 'SPs creados correctamente' AS info;
GO