CREATE USER [madevelopers] FROM EXTERNAL PROVIDER
GO

CREATE USER [maplatformdblocal] FROM EXTERNAL PROVIDER
GO

CREATE ROLE [db_executor]
GO

GRANT EXECUTE TO db_executor
GO

EXECUTE sp_addrolemember 'db_executor', 'maplatformdblocal'
GO

EXECUTE sp_addrolemember 'db_owner', 'madevelopers'
GO

