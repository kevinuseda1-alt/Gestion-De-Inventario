-- Ejecuta este archivo completo en SSMS, en tu instancia de Bike Store.
-- Agrega vistas en español. No borra registros ni cambia nombres de las tablas.
-- Requiere haber ejecutado la reparación de inventario correctamente.
USE [Bike_Store];
GO
CREATE OR ALTER VIEW dbo.[Clientes] AS
SELECT [customer_id] AS [IdCliente],
       [first_name] AS [Nombres],
       [last_name] AS [Apellidos],
       [phone] AS [Telefono],
       [email] AS [Correo],
       [street] AS [Direccion],
       [city] AS [Ciudad],
       [state] AS [Departamento],
       [create_date] AS [FechaRegistro]
FROM dbo.[customers];
GO

CREATE OR ALTER VIEW dbo.[Categorias] AS
SELECT [category_id] AS [IdCategoria],
       [category_name] AS [NombreCategoria]
FROM dbo.[categories];
GO

CREATE OR ALTER VIEW dbo.[Productos] AS
SELECT [product_id] AS [IdProducto],
       [product_name] AS [NombreProducto],
       [model_year] AS [AnioModelo],
       [price] AS [PrecioCordobas],
       [imagen] AS [Imagen],
       [category_id] AS [IdCategoria],
       [create_date] AS [FechaRegistro],
       [min_stock] AS [ExistenciasMinimas],
       [is_active] AS [Activo]
FROM dbo.[products];
GO

CREATE OR ALTER VIEW dbo.[Usuarios] AS
SELECT [user_id] AS [IdUsuario],
       [username] AS [Usuario],
       [full_name] AS [NombreCompleto],
       [email] AS [Correo],
       [role] AS [Rol],
       [is_active] AS [Activo],
       [created_at] AS [FechaRegistro],
       [last_login] AS [UltimoAcceso]
FROM dbo.[users];
GO

CREATE OR ALTER VIEW dbo.[Pedidos] AS
SELECT [order_id] AS [IdPedido],
       [customer_id] AS [IdCliente],
       [user_id] AS [IdUsuario],
       [order_date] AS [FechaPedido]
FROM dbo.[orders];
GO

CREATE OR ALTER VIEW dbo.[DetallePedidos] AS
SELECT [order_item_id] AS [IdDetalle],
       [order_id] AS [IdPedido],
       [product_id] AS [IdProducto],
       [quantity] AS [Cantidad],
       [price] AS [PrecioCordobas],
       [discount] AS [Descuento]
FROM dbo.[order_items];
GO

CREATE OR ALTER VIEW dbo.[MovimientosInventario] AS
SELECT [inventory_id] AS [IdMovimiento],
       [product_id] AS [IdProducto],
       [quantity] AS [Cantidad],
       [movement_type] AS [TipoMovimiento],
       [user_id] AS [IdUsuario],
       [order_id] AS [IdPedido],
       [notes] AS [Observaciones],
       [movement_date] AS [FechaMovimiento]
FROM dbo.[inventory];
GO

CREATE OR ALTER VIEW dbo.[Proveedores] AS
SELECT [supplier_id] AS [IdProveedor],
       [supplier_name] AS [NombreProveedor],
       [contact_name] AS [PersonaContacto],
       [phone] AS [Telefono],
       [email] AS [Correo],
       [address] AS [Direccion],
       [is_active] AS [Activo],
       [created_at] AS [FechaRegistro]
FROM dbo.[suppliers];
GO

CREATE OR ALTER VIEW dbo.[ProductoProveedores] AS
SELECT [product_id] AS [IdProducto],
       [supplier_id] AS [IdProveedor]
FROM dbo.[product_suppliers];
GO

CREATE OR ALTER VIEW dbo.[ResumenInventario] AS
SELECT [product_id] AS [IdProducto],
       [product_name] AS [NombreProducto],
       [price] AS [PrecioCordobas],
       [min_stock] AS [ExistenciasMinimas],
       [stock_actual] AS [ExistenciasActuales]
FROM dbo.[vw_inventory_summary];
GO

-- Resultados en español.
USE [Bike_Store];
GO
-- Todos los registros, con encabezados en español. Los usuarios no muestran contraseñas.
SELECT * FROM dbo.[Clientes];
GO
SELECT * FROM dbo.[Categorias];
GO
SELECT * FROM dbo.[Productos];
GO
SELECT * FROM dbo.[Usuarios];
GO
SELECT * FROM dbo.[Pedidos];
GO
SELECT * FROM dbo.[DetallePedidos];
GO
SELECT * FROM dbo.[MovimientosInventario];
GO
SELECT * FROM dbo.[Proveedores];
GO
SELECT * FROM dbo.[ProductoProveedores];
GO
SELECT * FROM dbo.[ResumenInventario];
GO
