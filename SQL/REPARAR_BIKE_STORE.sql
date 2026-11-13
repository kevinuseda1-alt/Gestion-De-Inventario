:ON ERROR EXIT
-- Ejecutar archivo completo con sqlcmd -b, o en SSMS con modo SQLCMD.
USE [Bike_Store];
GO
SET XACT_ABORT ON;
IF DB_NAME() <> N'Bike_Store' THROW 51000,N'Base incorrecta.',1;
IF OBJECT_ID(N'dbo.users',N'U') IS NULL OR OBJECT_ID(N'dbo.products',N'U') IS NULL
 OR OBJECT_ID(N'dbo.categories',N'U') IS NULL OR OBJECT_ID(N'dbo.customers',N'U') IS NULL
 OR OBJECT_ID(N'dbo.orders',N'U') IS NULL OR OBJECT_ID(N'dbo.order_items',N'U') IS NULL
 OR OBJECT_ID(N'dbo.inventory',N'U') IS NULL
 THROW 51000,N'Esquema base incompleto. Restaurar respaldo compatible antes de reparar.',1;
BEGIN TRANSACTION;
GO
IF COL_LENGTH(N'dbo.users', N'password_hash') IS NULL
    ALTER TABLE dbo.users ADD password_hash VARBINARY(64) NULL;
GO
IF COL_LENGTH(N'dbo.users', N'password_salt') IS NULL
    ALTER TABLE dbo.users ADD password_salt VARBINARY(32) NULL;
GO
IF OBJECT_ID(N'dbo.suppliers', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.suppliers (
        supplier_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        supplier_name NVARCHAR(120) NOT NULL,
        contact_name NVARCHAR(120) NULL,
        phone NVARCHAR(30) NULL,
        email NVARCHAR(150) NULL,
        address NVARCHAR(250) NULL,
        is_active BIT NOT NULL CONSTRAINT DF_suppliers_active DEFAULT(1),
        created_at DATETIME2 NOT NULL CONSTRAINT DF_suppliers_created DEFAULT(SYSDATETIME())
    );
END;
GO
IF OBJECT_ID(N'dbo.product_suppliers', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.product_suppliers (
        product_id INT NOT NULL,
        supplier_id INT NOT NULL,
        CONSTRAINT PK_product_suppliers PRIMARY KEY(product_id,supplier_id),
        CONSTRAINT FK_ps_product FOREIGN KEY(product_id) REFERENCES dbo.products(product_id),
        CONSTRAINT FK_ps_supplier FOREIGN KEY(supplier_id) REFERENCES dbo.suppliers(supplier_id)
    );
END;
GO
IF COL_LENGTH(N'dbo.products', N'min_stock') IS NULL
    ALTER TABLE dbo.products ADD min_stock INT NOT NULL CONSTRAINT DF_products_min_stock DEFAULT(5);
GO
IF COL_LENGTH(N'dbo.products', N'is_active') IS NULL
    ALTER TABLE dbo.products ADD is_active BIT NOT NULL CONSTRAINT DF_products_is_active DEFAULT(1);
GO
CREATE OR ALTER VIEW dbo.vw_inventory_summary AS
SELECT p.product_id,p.product_name,p.price,p.min_stock,
       ISNULL(SUM(CASE WHEN i.movement_type='ENTRADA' THEN i.quantity
                       WHEN i.movement_type='SALIDA' THEN -i.quantity ELSE 0 END),0) AS stock_actual
FROM dbo.products p LEFT JOIN dbo.inventory i ON i.product_id=p.product_id
WHERE p.is_active=1
GROUP BY p.product_id,p.product_name,p.price,p.min_stock;
GO
CREATE OR ALTER PROCEDURE dbo.speliminar_products @product_id INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.products SET is_active=0 WHERE product_id=@product_id AND is_active=1;
    SELECT @@ROWCOUNT AS filas_afectadas;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spmostrar_products
AS
BEGIN
    SELECT p.product_id,p.product_name,p.model_year,p.price,p.imagen,p.category_id,
           p.create_date,c.category_name AS Category
    FROM dbo.products p INNER JOIN dbo.categories c ON c.category_id=p.category_id
    WHERE p.is_active=1 ORDER BY p.product_id DESC;
END;
GO
-- Una entrada/salida y su verificación de saldo se ejecutan bajo el mismo bloqueo.
CREATE OR ALTER PROCEDURE dbo.sp_registrar_movimiento_inventario
    @product_id INT,@quantity INT,@movement_type VARCHAR(20),@user_id INT,
    @order_id INT=NULL,@notes VARCHAR(255)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @quantity<=0 OR @quantity IS NULL THROW 51001,N'Cantidad inválida.',1;
    IF @movement_type NOT IN ('ENTRADA','SALIDA') OR @movement_type IS NULL
        THROW 51002,N'Tipo de movimiento inválido.',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS(SELECT 1 FROM dbo.products WITH (UPDLOCK,HOLDLOCK) WHERE product_id=@product_id AND is_active=1)
            THROW 51003,N'Producto inexistente.',1;
        IF @movement_type='SALIDA'
        BEGIN
            DECLARE @stock INT;
            SELECT @stock=ISNULL(SUM(CASE WHEN movement_type='ENTRADA' THEN quantity ELSE -quantity END),0)
            FROM dbo.inventory WITH (UPDLOCK,HOLDLOCK) WHERE product_id=@product_id;
            IF @stock<@quantity THROW 51004,N'Stock insuficiente.',1;
        END;
        INSERT dbo.inventory(product_id,quantity,movement_type,user_id,order_id,notes,movement_date)
        VALUES(@product_id,@quantity,@movement_type,@user_id,@order_id,@notes,GETDATE());
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.spmostrar_customers
as
begin
    select 
        customer_id,
        first_name,
        last_name,
        phone,
        email,
        street,
        city,
        state,
        create_date
    from customers
    order by customer_id desc
end

GO

CREATE OR ALTER PROCEDURE dbo.spinsertar_customers
    @customer_id int,
    @first_name varchar(255),
    @last_name varchar(255),
    @phone varchar(25),
    @email varchar(255),
    @street varchar(255),
    @city varchar(50),
    @state varchar(25)
as
begin
    insert into customers(
        customer_id,
        first_name,
        last_name,
        phone,
        email,
        street,
        city,
        state,
        create_date
    )
    values (
        @customer_id,
        @first_name,
        @last_name,
        @phone,
        @email,
        @street,
        @city,
        @state,
        getdate()
    )
end

GO

CREATE OR ALTER PROCEDURE dbo.speditar_customers
    @customer_id int,
    @first_name varchar(255),
    @last_name varchar(255),
    @phone varchar(25),
    @email varchar(255),
    @street varchar(255),
    @city varchar(50),
    @state varchar(25)
as
begin
    update customers set 
        first_name = @first_name,
        last_name = @last_name,
        phone = @phone,
        email = @email,
        street = @street,
        city = @city,
        state = @state
    where customer_id = @customer_id
end

GO

CREATE OR ALTER PROCEDURE dbo.speliminar_customers
    @customer_id int
as
begin
    delete from customers
    where customer_id = @customer_id
end

GO

CREATE OR ALTER PROCEDURE dbo.spbuscar_customers
    @column_name varchar(100) = null,
    @search_value varchar(255) = null,
    @textobuscar varchar(255) = null
as
begin
    set nocount on;

    if @textobuscar is not null
    begin
        select *
        from customers
        where first_name like '%' + @textobuscar + '%'
           or last_name like '%' + @textobuscar + '%'
           or email like '%' + @textobuscar + '%'
        order by customer_id desc;
        return;
    end;

    if @column_name not in ('customer_id','first_name','last_name','phone','email','street','city','state')
    begin
        raiserror('Columna de búsqueda no válida', 16, 1);
        return;
    end;

    declare @sql nvarchar(max);
    declare @patron varchar(260);

    set @sql = N'select * from customers where ' + quotename(@column_name) +
               N' like @patron order by customer_id desc';

    set @patron = '%' + isnull(@search_value, '') + '%';

    exec sp_executesql
        @sql,
        N'@patron varchar(260)',
        @patron = @patron;
end

GO

CREATE OR ALTER PROCEDURE dbo.spinsertar_categories
    @category_id int output,
    @category_name varchar(255)
as
begin
    insert into categories(category_name)
    values (@category_name)
    set @category_id = SCOPE_IDENTITY()
end

GO

CREATE OR ALTER PROCEDURE dbo.speditar_categories
    @category_id int,
    @category_name varchar(255)
as
begin
    update categories set 
        category_name = @category_name
    where category_id = @category_id
end

GO

CREATE OR ALTER PROCEDURE dbo.speliminar_categories
    @category_id int
as
begin
    delete from categories
    where category_id = @category_id
end

GO

CREATE OR ALTER PROCEDURE dbo.spmostrar_categories
as
begin
    select category_id, category_name 
    from categories
    order by category_id desc
end

GO

CREATE OR ALTER PROCEDURE dbo.spbuscar_categories
    @textobuscar varchar(50)
as
begin
    select category_id, category_name 
    from categories
    where category_name like '%' + @textobuscar + '%'
    order by category_id desc
end

GO

CREATE OR ALTER PROCEDURE dbo.spinsertar_products
    @product_id int output,
    @product_name varchar(200),
    @model_year smallint,
    @price decimal(10,2),
    @imagen image,
    @category_id int,
    @create_date date
as
begin
    insert into products(product_name, model_year, price, imagen, category_id, create_date)
    values (@product_name, @model_year, @price, @imagen, @category_id, @create_date)
    set @product_id = SCOPE_IDENTITY()
end

GO

CREATE OR ALTER PROCEDURE dbo.speditar_products
    @product_id int,
    @product_name varchar(200),
    @model_year smallint,
    @price decimal(10,2),
    @imagen image,
    @category_id int,
    @create_date date
as
begin
    update products set 
        product_name = @product_name,
        model_year = @model_year,
        price = @price,
        imagen = @imagen,
        category_id = @category_id,
        create_date = @create_date
    where product_id = @product_id
end

GO

CREATE OR ALTER PROCEDURE dbo.speliminar_products
    @product_id int
as
begin
    delete from products
    where product_id = @product_id
end

GO

CREATE OR ALTER PROCEDURE dbo.spmostrar_products
as
begin
    select 
        p.product_id,
        p.product_name,
        p.model_year,
        p.price,
        p.imagen,
        p.category_id,
        p.create_date,
        c.category_name as Category
    from products p 
    inner join categories c on p.category_id = c.category_id
    order by p.product_id desc
end

GO

CREATE OR ALTER PROCEDURE dbo.spbuscar_product_name
    @textbuscar varchar(50)
as
begin
    select 
        p.product_id,
        p.product_name,
        p.model_year,
        p.price,
        p.imagen,
        p.category_id,
        p.create_date,
        c.category_name as Category
    from products p 
    inner join categories c on p.category_id = c.category_id
where p.is_active=1 AND product_name like '%' + @textbuscar + '%'
order by p.product_id desc
end

GO

CREATE OR ALTER PROCEDURE dbo.sp_login_user
    @username varchar(50),
    @password varchar(255)
as
begin
    select user_id, username, full_name, email, role, is_active
    from users 
    where username = @username AND password = @password and is_active = 1
end

GO

CREATE OR ALTER PROCEDURE dbo.sp_create_user
    @username varchar(50),
    @password varchar(255),
    @full_name varchar(100),
    @email varchar(100),
    @role varchar(20),
    @user_id int output
as
begin
    insert into users (username, password, full_name, email, role)
    values (@username, @password, @full_name, @email, @role)
    set @user_id = scope_identity()
end

GO

CREATE OR ALTER PROCEDURE dbo.sp_get_all_users
as
begin
    select user_id, username, full_name, email, role, is_active, 
           convert(varchar, created_at, 103) as created_date,
           convert(varchar, last_login, 103) as last_login_date
    from users
    order by username
end

GO

CREATE OR ALTER PROCEDURE dbo.sp_update_user
    @user_id int,
    @username varchar(50),
    @full_name varchar(100),
    @email varchar(100),
    @role varchar(20),
    @is_active bit
as
begin
    update users set
        username = @username,
        full_name = @full_name,
        email = @email,
        role = @role,
        is_active = @is_active
    where user_id = @user_id
end

GO

CREATE OR ALTER PROCEDURE dbo.sp_delete_user
    @user_id int
as
begin
    delete from users where user_id = @user_id
end

GO

CREATE OR ALTER PROCEDURE dbo.sp_search_users
    @search_text varchar(100)
as
begin
    select user_id, username, full_name, email, role, is_active, 
           convert(varchar, created_at, 103) as created_date
    from users
    where username LIKE '%' + @search_text + '%' OR 
          full_name LIKE '%' + @search_text + '%' OR
          email LIKE '%' + @search_text + '%'
    order by username
end

GO

CREATE OR ALTER PROCEDURE dbo.sp_change_password
    @user_id int,
    @new_password varchar(255)
as
begin
    update users set password = @new_password 
    where user_id = @user_id
end

GO

CREATE OR ALTER PROCEDURE dbo.sp_verify_user
    @user_id int,
    @email varchar(100),
    @username varchar(100)
as
begin
    set nocount on;

    declare @NormalizedEmail varchar(100) = lower(ltrim(rtrim(@email)));
    declare @NormalizedName varchar(100) = lower(ltrim(rtrim(@username)));

    select 
        user_id,
        username,
        full_name,
        email,
        role,
        is_active
    from users
    where user_id = @user_id
      and lower(ltrim(rtrim(email))) = @NormalizedEmail
      and lower(ltrim(rtrim(full_name))) like '%' + @NormalizedName + '%'
      and is_active = 1;
end

GO

CREATE OR ALTER PROCEDURE dbo.spinsertar_order_items
    @order_item_id int = null output,
    @order_id int,
    @product_id int,
    @quantity int,
    @price decimal(10,2),
    @discount decimal(10,2)
as
begin
    set nocount on;
    insert into order_items(order_id, product_id, quantity, price, discount)
    values(@order_id, @product_id, @quantity, @price, @discount);

    set @order_item_id = scope_identity();
end

GO

CREATE OR ALTER PROCEDURE dbo.speliminar_order
    @order_id int
as
begin
    set nocount off;
    begin try
        begin transaction;

        delete from inventory
        where order_id = @order_id;

        delete from order_items
        where order_id = @order_id;

        delete from orders
        where order_id = @order_id;

        commit transaction;
    end try
    begin catch
        if @@trancount > 0 rollback transaction;
        raiserror('No se pudo eliminar el pedido.', 16, 1);
    end catch
end

GO

CREATE OR ALTER PROCEDURE dbo.spmostrar_order
as
begin
    select 
        o.order_id,
        u.full_name as usuario,
        (c.first_name + ' ' + c.last_name) as Cliente,
        o.order_date,
        sum((oi.quantity * oi.price) - oi.discount) as Total, o.customer_id
    from order_items oi 
    inner join orders o on oi.order_id = o.order_id
    left join customers c on o.customer_id = c.customer_id
    left join users u on o.user_id = u.user_id
    group by o.order_id, u.full_name, c.first_name, c.last_name, o.order_date, o.customer_id
    order by o.order_id desc
end

GO

CREATE OR ALTER PROCEDURE dbo.spbuscar_order_fecha
    @textobuscar1 datetime,
    @textobuscar2 datetime
as
begin
    select 
        o.order_id,
        u.full_name as usuario,
        (c.first_name + ' ' + c.last_name) as Cliente,
        o.order_date,
        sum((oi.quantity * oi.price) - oi.discount) as Total, o.customer_id
    from order_items oi 
    inner join orders o on oi.order_id = o.order_id
    left join customers c on o.customer_id = c.customer_id
    left join users u on o.user_id = u.user_id
    group by o.order_id, u.full_name, c.first_name, c.last_name, o.order_date, o.customer_id
    having o.order_date >= CONVERT(date,@textobuscar1) and o.order_date < DATEADD(day,1,CONVERT(date,@textobuscar2)) 
    order by o.order_id desc 
end

GO

CREATE OR ALTER PROCEDURE dbo.spmostrar_order_items
    @textobuscar varchar(50)
as
begin
    select 
        oi.product_id,
        p.product_name as Producto,
        oi.quantity,
        oi.price,
        oi.discount,
        ((oi.price * oi.quantity) - oi.discount) as Subtotal
    from order_items oi 
    left join products p on oi.product_id = p.product_id
    where oi.order_id = @textobuscar
    order by oi.order_item_id
end

GO

CREATE OR ALTER PROCEDURE dbo.sp_rpt_obtener_cabecera_pedido
    @pedido_id int
as
begin
    select 
        o.order_id,
        c.first_name + ' ' + c.last_name as nombre_cliente,
        c.email,
        c.phone,
        c.street + ', ' + isnull(c.city, '') + ', ' + isnull(c.state, '') as direccion_completa,
        u.full_name as usuario,
        o.order_date as fecha_pedido,
        (select sum(quantity * price - discount) from order_items where order_id = o.order_id) as total
    from orders o
    inner join customers c on o.customer_id = c.customer_id
    inner join users u on o.user_id = u.user_id
    where o.order_id = @pedido_id
end

GO

CREATE OR ALTER PROCEDURE dbo.sp_rpt_obtener_detalle_pedido
    @pedido_id int
as
begin
    select 
        oi.product_id,
        p.product_name as producto,
        oi.quantity as cantidad,
        oi.price as precio,
        oi.discount as descuento,
        ((oi.price * oi.quantity) - oi.discount) as subtotal
    from order_items oi 
    left join products p on oi.product_id = p.product_id
    where oi.order_id = @pedido_id
    order by oi.order_item_id
end

GO

CREATE OR ALTER PROCEDURE dbo.sp_consultar_clientes_para_reporte
as
begin
    select 
        customer_id,
        first_name + ' ' + last_name as nombre_completo,
        email, 
        phone as telefono
    from customers
    order by last_name, first_name
end

GO

CREATE OR ALTER PROCEDURE dbo.sp_buscar_clientes_para_reporte
    @criterio_busqueda varchar(100)
as
begin
    select 
        customer_id,
        first_name + ' ' + last_name as nombre_completo,
        email, 
        phone as telefono
    from customers
    where first_name like '%' + @criterio_busqueda + '%'
    or last_name like '%' + @criterio_busqueda + '%'
    or email like '%' + @criterio_busqueda + '%'
    order by last_name, first_name
end

GO

CREATE OR ALTER PROCEDURE dbo.sp_consultar_productos_para_reporte
as
begin
    select  
        p.product_id, 
        p.product_name as producto, 
        p.price as precio, 
        p.model_year as año_modelo,
        c.category_name as categoria
    from products p
    inner join categories c on p.category_id = c.category_id
    order by product_name
end

GO

CREATE OR ALTER PROCEDURE dbo.sp_buscar_productos_para_reporte
    @criterio_busqueda varchar(100)
as
begin
    select 
        p.product_id, 
        p.product_name as producto, 
        p.price as precio,
        p.model_year as año_modelo,
        c.category_name as categoria
    from products p
    inner join categories c on p.category_id = c.category_id
    where (p.product_name like '%' + @criterio_busqueda + '%'
    or cast(p.product_id as varchar(20)) like '%' + @criterio_busqueda + '%')
    order by product_name
end

GO

CREATE OR ALTER PROCEDURE dbo.spbuscar_products
    @textobuscar varchar(50)
as
begin
    select 
        p.product_id,
        p.product_name,
        p.model_year,
        p.price,
        p.imagen,
        p.category_id,
        p.create_date,
        c.category_name as Category
    from products p
    inner join categories c on p.category_id = c.category_id
    where p.is_active=1 AND p.product_name like '%' + @textobuscar + '%'
    order by p.product_id desc;
end

GO

CREATE OR ALTER PROCEDURE dbo.sp_filtrar_productos_por_fecha
    @fecha_inicio datetime,
    @fecha_fin datetime
as
begin
    select 
        p.product_id,
        p.product_name,
        p.model_year,
        p.price,
        p.imagen,
        p.category_id,
        p.create_date,
        c.category_name as Category
    from products p
    inner join categories c on p.category_id = c.category_id
    where p.is_active=1 AND p.create_date >= @fecha_inicio
      and p.create_date <= @fecha_fin
    order by p.create_date desc, p.product_id desc;
end

GO

CREATE OR ALTER PROCEDURE dbo.spinsertar_orders
    @customer_id int,
    @user_id int,
    @order_id int output
as
begin
    insert into orders(customer_id, user_id, order_date)
    values (@customer_id, @user_id, getdate())
    set @order_id = scope_identity()
end

GO

CREATE OR ALTER PROCEDURE dbo.sp_obtener_estadisticas_dashboard
as
begin
    declare @totalClientes int = (select count(*) from customers)
    declare @totalProductos int = (select count(*) from products)
    declare @ventasMes decimal(10,2) = (
        select isnull(sum((oi.quantity * oi.price) - oi.discount), 0)
        from order_items oi
        inner join orders o on oi.order_id = o.order_id
        where month(o.order_date) = month(getdate()) 
        and year(o.order_date) = year(getdate())
    )
    declare @pedidosRecientes int = (
        select count(*) from orders 
        where datediff(day, order_date, getdate()) <= 7
    )
    declare @adminName varchar(100), @adminEmail varchar(100)
    select top 1 @adminName = full_name, @adminEmail = email 
    from users where role = 'admin'
    select 
        @totalClientes as total_clientes,
        @totalProductos as total_productos,
        @ventasMes as ventas_mes,
        @pedidosRecientes as pedidos_recientes,
        @adminName as admin_nombre,
        @adminEmail as admin_email
end

GO

CREATE OR ALTER PROCEDURE dbo.sp_registrar_movimiento_inventario
    @product_id int,
    @quantity int,
    @movement_type varchar(20),
    @user_id int,
    @order_id int = null,
    @notes varchar(255) = null
as
begin
    set nocount on;

    if @quantity <= 0
    begin
        raiserror('La cantidad debe ser mayor a cero.', 16, 1);
        return;
    end;

    if @movement_type not in ('ENTRADA','SALIDA')
    begin
        raiserror('Tipo de movimiento no válido.', 16, 1);
        return;
    end;

    if @movement_type = 'SALIDA'
    begin
        declare @stock_actual int;
        select @stock_actual = isnull(sum(
            case when movement_type = 'ENTRADA' then quantity
                 when movement_type = 'SALIDA' then -quantity
                 else 0 end), 0)
        from inventory
        where product_id = @product_id;

        if @quantity > @stock_actual
        begin
            raiserror('Stock insuficiente para realizar la salida.', 16, 1);
            return;
        end;
    end;

    insert into inventory (product_id, quantity, movement_type, user_id, order_id, notes, movement_date)
    values (@product_id, @quantity, @movement_type, @user_id, @order_id, @notes, getdate());
end

GO

CREATE OR ALTER PROCEDURE dbo.sp_actualizar_stock_calculado
    @product_id int
as
begin
    set nocount on;
    select isnull(sum(
        case when movement_type = 'ENTRADA' then quantity
             when movement_type = 'SALIDA' then -quantity
             else 0 end), 0) as stock_actual
    from inventory
    where product_id = @product_id;
end

GO

CREATE OR ALTER PROCEDURE dbo.sp_obtener_stock
    @product_id int
as
begin
    select isnull(sum(
        case when movement_type = 'ENTRADA' then quantity 
             when movement_type = 'SALIDA' then -quantity 
             else 0 end), 0) as stock_actual
    from inventory
    where product_id = @product_id;
end

GO

CREATE OR ALTER PROCEDURE dbo.sp_reducir_stock
    @product_id int,
    @cantidad int
as
begin
    declare @user_id int = (select top 1 user_id from users where is_active = 1 order by user_id);
    exec sp_registrar_movimiento_inventario
        @product_id = @product_id,
        @quantity = @cantidad,
        @movement_type = 'SALIDA',
        @user_id = @user_id,
        @order_id = null,
        @notes = 'Salida manual mediante sp_reducir_stock';
end

GO

CREATE OR ALTER PROCEDURE dbo.sp_aumentar_stock
    @product_id int,
    @cantidad int
as
begin
    declare @user_id int = (select top 1 user_id from users where is_active = 1 order by user_id);
    exec sp_registrar_movimiento_inventario
        @product_id = @product_id,
        @quantity = @cantidad,
        @movement_type = 'ENTRADA',
        @user_id = @user_id,
        @order_id = null,
        @notes = 'Entrada manual mediante sp_aumentar_stock';
end

GO

CREATE OR ALTER PROCEDURE dbo.speliminar_order_items
    @order_id int
as
begin
    delete from order_items where order_id = @order_id
end

GO
IF COL_LENGTH(N'dbo.users', N'password_hash') IS NULL
    ALTER TABLE dbo.users ADD password_hash VARBINARY(64) NULL;
GO
IF COL_LENGTH(N'dbo.users', N'password_salt') IS NULL
    ALTER TABLE dbo.users ADD password_salt VARBINARY(32) NULL;
GO
IF OBJECT_ID(N'dbo.suppliers', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.suppliers (
        supplier_id INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
        supplier_name NVARCHAR(120) NOT NULL,
        contact_name NVARCHAR(120) NULL,
        phone NVARCHAR(30) NULL,
        email NVARCHAR(150) NULL,
        address NVARCHAR(250) NULL,
        is_active BIT NOT NULL CONSTRAINT DF_suppliers_active DEFAULT(1),
        created_at DATETIME2 NOT NULL CONSTRAINT DF_suppliers_created DEFAULT(SYSDATETIME())
    );
END;
GO
IF OBJECT_ID(N'dbo.product_suppliers', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.product_suppliers (
        product_id INT NOT NULL,
        supplier_id INT NOT NULL,
        CONSTRAINT PK_product_suppliers PRIMARY KEY(product_id,supplier_id),
        CONSTRAINT FK_ps_product FOREIGN KEY(product_id) REFERENCES dbo.products(product_id),
        CONSTRAINT FK_ps_supplier FOREIGN KEY(supplier_id) REFERENCES dbo.suppliers(supplier_id)
    );
END;
GO
IF COL_LENGTH(N'dbo.products', N'min_stock') IS NULL
    ALTER TABLE dbo.products ADD min_stock INT NOT NULL CONSTRAINT DF_products_min_stock DEFAULT(5);
GO
IF COL_LENGTH(N'dbo.products', N'is_active') IS NULL
    ALTER TABLE dbo.products ADD is_active BIT NOT NULL CONSTRAINT DF_products_is_active DEFAULT(1);
GO
CREATE OR ALTER VIEW dbo.vw_inventory_summary AS
SELECT p.product_id,p.product_name,p.price,p.min_stock,
       ISNULL(SUM(CASE WHEN i.movement_type='ENTRADA' THEN i.quantity
                       WHEN i.movement_type='SALIDA' THEN -i.quantity ELSE 0 END),0) AS stock_actual
FROM dbo.products p LEFT JOIN dbo.inventory i ON i.product_id=p.product_id
WHERE p.is_active=1
GROUP BY p.product_id,p.product_name,p.price,p.min_stock;
GO
CREATE OR ALTER PROCEDURE dbo.speliminar_products @product_id INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE dbo.products SET is_active=0 WHERE product_id=@product_id AND is_active=1;
    SELECT @@ROWCOUNT AS filas_afectadas;
END;
GO
CREATE OR ALTER PROCEDURE dbo.spmostrar_products
AS
BEGIN
    SELECT p.product_id,p.product_name,p.model_year,p.price,p.imagen,p.category_id,
           p.create_date,c.category_name AS Category
    FROM dbo.products p INNER JOIN dbo.categories c ON c.category_id=p.category_id
    WHERE p.is_active=1 ORDER BY p.product_id DESC;
END;
GO
-- Una entrada/salida y su verificación de saldo se ejecutan bajo el mismo bloqueo.
CREATE OR ALTER PROCEDURE dbo.sp_registrar_movimiento_inventario
    @product_id INT,@quantity INT,@movement_type VARCHAR(20),@user_id INT,
    @order_id INT=NULL,@notes VARCHAR(255)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    IF @quantity<=0 OR @quantity IS NULL THROW 51001,N'Cantidad inválida.',1;
    IF @movement_type NOT IN ('ENTRADA','SALIDA') OR @movement_type IS NULL
        THROW 51002,N'Tipo de movimiento inválido.',1;
    BEGIN TRY
        BEGIN TRANSACTION;
        IF NOT EXISTS(SELECT 1 FROM dbo.products WITH (UPDLOCK,HOLDLOCK) WHERE product_id=@product_id AND is_active=1)
            THROW 51003,N'Producto inexistente.',1;
        IF @movement_type='SALIDA'
        BEGIN
            DECLARE @stock INT;
            SELECT @stock=ISNULL(SUM(CASE WHEN movement_type='ENTRADA' THEN quantity ELSE -quantity END),0)
            FROM dbo.inventory WITH (UPDLOCK,HOLDLOCK) WHERE product_id=@product_id;
            IF @stock<@quantity THROW 51004,N'Stock insuficiente.',1;
        END;
        INSERT dbo.inventory(product_id,quantity,movement_type,user_id,order_id,notes,movement_date)
        VALUES(@product_id,@quantity,@movement_type,@user_id,@order_id,@notes,GETDATE());
        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END;
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

GO
COMMIT TRANSACTION;
GO
PRINT N'Reparación completada sin reemplazar datos.';
