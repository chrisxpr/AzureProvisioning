CREATE USER [{DeveloperGroup}] FROM EXTERNAL PROVIDER
GO

CREATE USER [{ServiceAccount}] FROM EXTERNAL PROVIDER
GO

CREATE ROLE [db_executor]
GO

GRANT EXECUTE TO db_executor
GO

EXECUTE sp_addrolemember 'db_executor', '{ServiceAccount}'
GO

EXECUTE sp_addrolemember 'db_owner', '{DeveloperGroup}'
GO