:ON ERROR EXIT
USE master;
GO
IF DB_ID(N'Bike_Store') IS NULL THROW 51000,N'No existe Bike_Store.',1;
DECLARE @folder nvarchar(4000)=CONVERT(nvarchar(4000),SERVERPROPERTY('InstanceDefaultBackupPath'));
IF @folder IS NULL THROW 51000,N'No se pudo obtener carpeta de respaldos.',1;
DECLARE @file nvarchar(4000)=@folder+N'\Bike_Store_antes_reparacion_'+CONVERT(nvarchar(36),NEWID())+N'.bak';
BACKUP DATABASE [Bike_Store] TO DISK=@file WITH COPY_ONLY,CHECKSUM;
RESTORE VERIFYONLY FROM DISK=@file WITH CHECKSUM;
SELECT @file AS RespaldoVerificado;
GO
