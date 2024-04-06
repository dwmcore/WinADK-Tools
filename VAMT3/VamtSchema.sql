/*
Deployment script for Vamt3
*/

GO
SET ANSI_NULLS, ANSI_PADDING, ANSI_WARNINGS, ARITHABORT, CONCAT_NULL_YIELDS_NULL, QUOTED_IDENTIFIER ON;

SET NUMERIC_ROUNDABORT OFF;


GO
:setvar DatabaseName "Vamt3"
:setvar DefaultDataPath ""
:setvar DefaultLogPath ""

GO
USE [master]

GO
:on error exit
GO
IF (DB_ID(N'$(DatabaseName)') IS NOT NULL
    AND DATABASEPROPERTYEX(N'$(DatabaseName)','Status') <> N'ONLINE')
BEGIN
    RAISERROR(N'The state of the target database, %s, is not set to ONLINE. To deploy to this database, its state must be set to ONLINE.', 16, 127,N'$(DatabaseName)') WITH NOWAIT
    RETURN
END

GO
IF (DB_ID(N'$(DatabaseName)') IS NOT NULL) 
BEGIN
    ALTER DATABASE [$(DatabaseName)]
    SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$(DatabaseName)];
END

GO
PRINT N'Creating $(DatabaseName)...'
GO
CREATE DATABASE [$(DatabaseName)] COLLATE SQL_Latin1_General_CP1_CI_AS
GO
EXECUTE sp_dbcmptlevel [$(DatabaseName)], 100;


GO
IF EXISTS (SELECT 1
           FROM   [master].[dbo].[sysdatabases]
           WHERE  [name] = N'$(DatabaseName)')
    BEGIN
        ALTER DATABASE [$(DatabaseName)]
            SET ANSI_NULLS ON,
                ANSI_PADDING ON,
                ANSI_WARNINGS ON,
                ARITHABORT ON,
                CONCAT_NULL_YIELDS_NULL ON,
                NUMERIC_ROUNDABORT OFF,
                QUOTED_IDENTIFIER ON,
                ANSI_NULL_DEFAULT ON,
                CURSOR_DEFAULT LOCAL,
                RECOVERY FULL,
                CURSOR_CLOSE_ON_COMMIT OFF,
                AUTO_CREATE_STATISTICS ON,
                AUTO_SHRINK OFF,
                AUTO_UPDATE_STATISTICS ON,
                RECURSIVE_TRIGGERS OFF 
            WITH ROLLBACK IMMEDIATE;
        ALTER DATABASE [$(DatabaseName)]
            SET AUTO_CLOSE OFF 
            WITH ROLLBACK IMMEDIATE;
    END


GO
IF EXISTS (SELECT 1
           FROM   [master].[dbo].[sysdatabases]
           WHERE  [name] = N'$(DatabaseName)')
    BEGIN
        ALTER DATABASE [$(DatabaseName)]
            SET ALLOW_SNAPSHOT_ISOLATION OFF;
    END


GO
IF EXISTS (SELECT 1
           FROM   [master].[dbo].[sysdatabases]
           WHERE  [name] = N'$(DatabaseName)')
    BEGIN
        ALTER DATABASE [$(DatabaseName)]
            SET READ_COMMITTED_SNAPSHOT OFF;
    END


GO
IF EXISTS (SELECT 1
           FROM   [master].[dbo].[sysdatabases]
           WHERE  [name] = N'$(DatabaseName)')
    BEGIN
        ALTER DATABASE [$(DatabaseName)]
            SET AUTO_UPDATE_STATISTICS_ASYNC OFF,
                PAGE_VERIFY NONE,
                DATE_CORRELATION_OPTIMIZATION OFF,
                DISABLE_BROKER,
                PARAMETERIZATION SIMPLE,
                SUPPLEMENTAL_LOGGING OFF 
            WITH ROLLBACK IMMEDIATE;
    END


GO
IF IS_SRVROLEMEMBER(N'sysadmin') = 1
    BEGIN
        IF EXISTS (SELECT 1
                   FROM   [master].[dbo].[sysdatabases]
                   WHERE  [name] = N'$(DatabaseName)')
            BEGIN
                EXECUTE sp_executesql N'ALTER DATABASE [$(DatabaseName)]
    SET TRUSTWORTHY OFF,
        DB_CHAINING OFF 
    WITH ROLLBACK IMMEDIATE';
            END
    END
ELSE
    BEGIN
        PRINT N'The database settings cannot be modified. You must be a SysAdmin to apply these settings.';
    END


GO
IF IS_SRVROLEMEMBER(N'sysadmin') = 1
    BEGIN
        IF EXISTS (SELECT 1
                   FROM   [master].[dbo].[sysdatabases]
                   WHERE  [name] = N'$(DatabaseName)')
            BEGIN
                EXECUTE sp_executesql N'ALTER DATABASE [$(DatabaseName)]
    SET HONOR_BROKER_PRIORITY OFF 
    WITH ROLLBACK IMMEDIATE';
            END
    END
ELSE
    BEGIN
        PRINT N'The database settings cannot be modified. You must be a SysAdmin to apply these settings.';
    END


GO
USE [$(DatabaseName)]

GO
IF fulltextserviceproperty(N'IsFulltextInstalled') = 1
    EXECUTE sp_fulltext_database 'enable';


GO
/*
 Pre-Deployment Script Template							
--------------------------------------------------------------------------------------
 This file contains SQL statements that will be executed before the build script.	
 Use SQLCMD syntax to include a file in the pre-deployment script.			
 Example:      :r .\myfile.sql								
 Use SQLCMD syntax to reference a variable in the pre-deployment script.		
 Example:      :setvar TableName MyTable							
               SELECT * FROM [$(TableName)]					
--------------------------------------------------------------------------------------
*/

GO
PRINT N'Creating [api]...';


GO
CREATE SCHEMA [api]
    AUTHORIZATION [dbo];


GO
PRINT N'Creating [base]...';


GO
CREATE SCHEMA [base]
    AUTHORIZATION [dbo];


GO
PRINT N'Creating [load]...';


GO
CREATE SCHEMA [load]
    AUTHORIZATION [dbo];


GO
PRINT N'Creating [dbo].[AdObjectDn]...';


GO
CREATE TYPE [dbo].[AdObjectDn]
    FROM NVARCHAR (255) NOT NULL;


GO
PRINT N'Creating [dbo].[AdObjectName]...';


GO
CREATE TYPE [dbo].[AdObjectName]
    FROM NVARCHAR (255) NOT NULL;


GO
PRINT N'Creating [dbo].[AVSErrorCode]...';


GO
CREATE TYPE [dbo].[AVSErrorCode]
    FROM INT NOT NULL;


GO
PRINT N'Creating [dbo].[ClientMachineID]...';


GO
CREATE TYPE [dbo].[ClientMachineID]
    FROM UNIQUEIDENTIFIER NOT NULL;


GO
PRINT N'Creating [dbo].[FullyQualifiedDomainName]...';


GO
CREATE TYPE [dbo].[FullyQualifiedDomainName]
    FROM NVARCHAR (255) NOT NULL;


GO
PRINT N'Creating [dbo].[LastActionStatusMsg]...';


GO
CREATE TYPE [dbo].[LastActionStatusMsg]
    FROM NVARCHAR (255) NOT NULL;


GO
PRINT N'Creating [dbo].[MACAddress]...';


GO
CREATE TYPE [dbo].[MACAddress]
    FROM NVARCHAR (20) NOT NULL;


GO
PRINT N'Creating [dbo].[MachineHostName]...';


GO
CREATE TYPE [dbo].[MachineHostName]
    FROM NVARCHAR (67) NOT NULL;


GO
PRINT N'Creating [dbo].[ProductConfirmationId]...';


GO
CREATE TYPE [dbo].[ProductConfirmationId]
    FROM NVARCHAR (48) NOT NULL;


GO
PRINT N'Creating [dbo].[ProductEdition]...';


GO
CREATE TYPE [dbo].[ProductEdition]
    FROM NVARCHAR (255) NOT NULL;


GO
PRINT N'Creating [dbo].[ProductInstallationId]...';


GO
CREATE TYPE [dbo].[ProductInstallationId]
    FROM NVARCHAR (63) NOT NULL;


GO
PRINT N'Creating [dbo].[ProductKey]...';


GO
CREATE TYPE [dbo].[ProductKey]
    FROM NCHAR (29) NOT NULL;


GO
PRINT N'Creating [dbo].[ProductKeyDescription]...';


GO
CREATE TYPE [dbo].[ProductKeyDescription]
    FROM NVARCHAR (255) NOT NULL;


GO
PRINT N'Creating [dbo].[ProductKeyId]...';


GO
CREATE TYPE [dbo].[ProductKeyId]
    FROM NVARCHAR (53) NOT NULL;


GO
PRINT N'Creating [dbo].[ProductKeySupportedEditions]...';


GO
CREATE TYPE [dbo].[ProductKeySupportedEditions]
    FROM NVARCHAR (255) NOT NULL;


GO
PRINT N'Creating [dbo].[ProductKeyType]...';


GO
CREATE TYPE [dbo].[ProductKeyType]
    FROM INT NOT NULL;


GO
PRINT N'Creating [dbo].[StatusText]...';


GO
CREATE TYPE [dbo].[StatusText]
    FROM NVARCHAR (256) NULL;


GO
PRINT N'Creating [dbo].[VamtErrorCode]...';


GO
CREATE TYPE [dbo].[VamtErrorCode]
    FROM INT NOT NULL;


GO
PRINT N'Creating [dbo].[VersionString]...';


GO
CREATE TYPE [dbo].[VersionString]
    FROM NVARCHAR (30) NOT NULL;


GO
PRINT N'Creating [dbo].[VolumeApplicationName]...';


GO
CREATE TYPE [dbo].[VolumeApplicationName]
    FROM NVARCHAR (255) NOT NULL;


GO
PRINT N'Creating [base].[ActiveProduct]...';


GO
CREATE TABLE [base].[ActiveProduct] (
    [FullyQualifiedDomainName] [dbo].[FullyQualifiedDomainName] NOT NULL,
    [ProductName]              [dbo].[VolumeApplicationName]    NULL,
    [ProductDescription]       [dbo].[VolumeApplicationName]    NULL,
    [ProductVersion]           [dbo].[VersionString]            NULL,
    [LicenseFamily]            [dbo].[ProductEdition]           NULL,
    [ApplicationId]            UNIQUEIDENTIFIER                 NOT NULL,
    [InstallationId]           [dbo].[ProductInstallationId]    NULL,
    [ConfirmationId]           [dbo].[ProductConfirmationId]    NULL,
    [SoftwareProvider]         INT                              NOT NULL,
    [ProductKeyId]             [dbo].[ProductKeyId]             NULL,
    [ProductKeyType]           [dbo].[ProductKeyType]           NOT NULL,
    [PartialProductKey]        NVARCHAR (5)                     NULL,
    [Sku]                      UNIQUEIDENTIFIER                 NOT NULL,
    [LicenseStatus]            INT                              NOT NULL,
    [LicenseStatusReason]      INT                              NOT NULL,
    [GraceExpirationDate]      DATETIME                         NULL,
    [ActionsAllowed]           INT                              NOT NULL,
    [GenuineStatus]            INT                              NOT NULL,
    [LicenseStatusLastUpdated] DATETIME                         NULL,
    [CMID]                     UNIQUEIDENTIFIER                 NULL,
    [KmsHost]                  [dbo].[FullyQualifiedDomainName] NULL,
    [KmsPort]                  INT                              NULL,
    [VLActivationType]         INT                              NOT NULL,
    [VLActivationTypeEnabled]  INT                              NOT NULL,
    [AdActivationObjectName]   [dbo].[AdObjectName]             NULL,
    [AdActivationObjectDN]     [dbo].[AdObjectDn]               NULL,
    [AdActivationCsvlkPid]     [dbo].[ProductKeyId]             NULL,
    [AdActivationCsvlkSkuId]   UNIQUEIDENTIFIER                 NULL,
    [LastActionStatus]         [dbo].[LastActionStatusMsg]      NOT NULL,
    [LastErrorCode]            INT                              NOT NULL,
    [LastUpdated]              DATETIME                         NULL,
    [ExportGuid]               UNIQUEIDENTIFIER                 NULL,
    [RowVer]                   TIMESTAMP                        NOT NULL
);


GO
PRINT N'Creating PK_ActiveProduct...';


GO
ALTER TABLE [base].[ActiveProduct]
    ADD CONSTRAINT [PK_ActiveProduct] PRIMARY KEY NONCLUSTERED ([FullyQualifiedDomainName] ASC, [ApplicationId] ASC, [Sku] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);


GO
PRINT N'Creating [base].[ActiveProduct].[IX_ActiveProduct_FullyQualifiedDomainName_ApplicationId]...';


GO
CREATE NONCLUSTERED INDEX [IX_ActiveProduct_FullyQualifiedDomainName_ApplicationId]
    ON [base].[ActiveProduct]([FullyQualifiedDomainName] ASC, [ApplicationId] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF, MAXDOP = 0);


GO
PRINT N'Creating [base].[ActiveProduct].[IX_ActiveProduct_ProductName_FullyQualifiedDomainName]...';


GO
CREATE NONCLUSTERED INDEX [IX_ActiveProduct_ProductName_FullyQualifiedDomainName]
    ON [base].[ActiveProduct]([ProductName] ASC, [FullyQualifiedDomainName] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF, MAXDOP = 0);


GO
PRINT N'Creating [base].[AppliedServiceDataFiles]...';


GO
CREATE TABLE [base].[AppliedServiceDataFiles] (
    [ServiceDataFileId] UNIQUEIDENTIFIER NOT NULL
);


GO
PRINT N'Creating PK_AppliedServiceDataFiles...';


GO
ALTER TABLE [base].[AppliedServiceDataFiles]
    ADD CONSTRAINT [PK_AppliedServiceDataFiles] PRIMARY KEY NONCLUSTERED ([ServiceDataFileId] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);


GO
PRINT N'Creating [base].[AvailableProduct]...';


GO
CREATE TABLE [base].[AvailableProduct] (
    [FullyQualifiedDomainName] [dbo].[FullyQualifiedDomainName] NOT NULL,
    [ApplicationId]            UNIQUEIDENTIFIER                 NOT NULL,
    [Sku]                      UNIQUEIDENTIFIER                 NOT NULL,
    [SoftwareProvider]         INT                              NOT NULL
);


GO
PRINT N'Creating PK_AvailableProduct...';


GO
ALTER TABLE [base].[AvailableProduct]
    ADD CONSTRAINT [PK_AvailableProduct] PRIMARY KEY NONCLUSTERED ([FullyQualifiedDomainName] ASC, [ApplicationId] ASC, [Sku] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);


GO
PRINT N'Creating [base].[CachedConfirmationId]...';


GO
CREATE TABLE [base].[CachedConfirmationId] (
    [InstallationId]           [dbo].[ProductInstallationId]    NOT NULL,
    [ConfirmationId]           [dbo].[ProductConfirmationId]    NOT NULL,
    [FullyQualifiedDomainName] [dbo].[FullyQualifiedDomainName] NOT NULL,
    [ApplicationId]            UNIQUEIDENTIFIER                 NOT NULL,
    [Sku]                      UNIQUEIDENTIFIER                 NOT NULL
);


GO
PRINT N'Creating PK_CachedConfirmationId...';


GO
ALTER TABLE [base].[CachedConfirmationId]
    ADD CONSTRAINT [PK_CachedConfirmationId] PRIMARY KEY NONCLUSTERED ([FullyQualifiedDomainName] ASC, [ApplicationId] ASC, [Sku] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);


GO
PRINT N'Creating [base].[CachedConfirmationId].[IX_CachedConfirmationId]...';


GO
CREATE NONCLUSTERED INDEX [IX_CachedConfirmationId]
    ON [base].[CachedConfirmationId]([InstallationId] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF, MAXDOP = 0);


GO
PRINT N'Creating [base].[GenuineStatusText]...';


GO
CREATE TABLE [base].[GenuineStatusText] (
    [GenuineStatus]     INT            NOT NULL,
    [ResourceLanguage]  NCHAR (10)     NOT NULL,
    [GenuineStatusText] NVARCHAR (255) NOT NULL
);


GO
PRINT N'Creating PK_GenuineStatusText...';


GO
ALTER TABLE [base].[GenuineStatusText]
    ADD CONSTRAINT [PK_GenuineStatusText] PRIMARY KEY CLUSTERED ([GenuineStatus] ASC, [ResourceLanguage] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);


GO
PRINT N'Creating [base].[GenuineStatusText].[IX_GenuineStatus]...';


GO
CREATE NONCLUSTERED INDEX [IX_GenuineStatus]
    ON [base].[GenuineStatusText]([GenuineStatus] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF, MAXDOP = 0);


GO
PRINT N'Creating [base].[GVLK]...';


GO
CREATE TABLE [base].[GVLK] (
    [KeyValue]          [dbo].[ProductKey]                  NOT NULL,
    [KeyId]             [dbo].[ProductKeyId]                NOT NULL,
    [KeyDescription]    [dbo].[ProductKeyDescription]       NOT NULL,
    [SupportedEditions] [dbo].[ProductKeySupportedEditions] NOT NULL,
    [SupportedSKU]      UNIQUEIDENTIFIER                    NOT NULL
);


GO
PRINT N'Creating PK_GVLK...';


GO
ALTER TABLE [base].[GVLK]
    ADD CONSTRAINT [PK_GVLK] PRIMARY KEY NONCLUSTERED ([KeyValue] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);


GO
PRINT N'Creating [base].[GVLK].[IX_GVLK_SupportedSku]...';


GO
CREATE NONCLUSTERED INDEX [IX_GVLK_SupportedSku]
    ON [base].[GVLK]([SupportedSKU] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF, MAXDOP = 0);


GO
PRINT N'Creating [base].[LicenseStatusText]...';


GO
CREATE TABLE [base].[LicenseStatusText] (
    [LicenseStatus]     INT            NOT NULL,
    [ResourceLanguage]  NCHAR (10)     NOT NULL,
    [LicenseStatusText] NVARCHAR (255) NOT NULL
);


GO
PRINT N'Creating PK_LicenseStatusText...';


GO
ALTER TABLE [base].[LicenseStatusText]
    ADD CONSTRAINT [PK_LicenseStatusText] PRIMARY KEY CLUSTERED ([LicenseStatus] ASC, [ResourceLanguage] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);


GO
PRINT N'Creating [base].[LicenseStatusText].[IX_LicenseStatus]...';


GO
CREATE NONCLUSTERED INDEX [IX_LicenseStatus]
    ON [base].[LicenseStatusText]([LicenseStatus] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF, MAXDOP = 0);


GO
PRINT N'Creating [base].[ProductKey]...';


GO
CREATE TABLE [base].[ProductKey] (
    [KeyValue]             [dbo].[ProductKey]                  NOT NULL,
    [KeyId]                [dbo].[ProductKeyId]                NOT NULL,
    [KeyType]              [dbo].[ProductKeyType]              NOT NULL,
    [KeyDescription]       [dbo].[ProductKeyDescription]       NOT NULL,
    [SupportedEditions]    [dbo].[ProductKeySupportedEditions] NOT NULL,
    [SupportedSKU]         UNIQUEIDENTIFIER                    NOT NULL,
    [UserRemarks]          [dbo].[ProductKeyDescription]       NOT NULL,
    [RemainingActivations] INT                                 NOT NULL,
    [LastUpdate]           DATETIME                            NULL,
    [LastErrorCode]        INT                                 NOT NULL,
    [RowVer]               TIMESTAMP                           NOT NULL
);


GO
PRINT N'Creating PK_ProductKey...';


GO
ALTER TABLE [base].[ProductKey]
    ADD CONSTRAINT [PK_ProductKey] PRIMARY KEY NONCLUSTERED ([KeyValue] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);


GO
PRINT N'Creating [base].[ProductKey].[IX_ProductKey_KeyType]...';


GO
CREATE NONCLUSTERED INDEX [IX_ProductKey_KeyType]
    ON [base].[ProductKey]([KeyType] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF, MAXDOP = 0);


GO
PRINT N'Creating [base].[ProductKey].[IX_ProductKey_SupportedSku]...';


GO
CREATE NONCLUSTERED INDEX [IX_ProductKey_SupportedSku]
    ON [base].[ProductKey]([SupportedSKU] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF, MAXDOP = 0);


GO
PRINT N'Creating [base].[ProductKeyTypeName]...';


GO
CREATE TABLE [base].[ProductKeyTypeName] (
    [KeyType]     INT           NOT NULL,
    [KeyTypeName] NVARCHAR (18) NULL
);


GO
PRINT N'Creating PK_ProductKeyTypeName...';


GO
ALTER TABLE [base].[ProductKeyTypeName]
    ADD CONSTRAINT [PK_ProductKeyTypeName] PRIMARY KEY CLUSTERED ([KeyType] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);


GO
PRINT N'Creating [base].[ProductMapping]...';


GO
CREATE TABLE [base].[ProductMapping] (
    [ActConfigId]   UNIQUEIDENTIFIER NOT NULL,
    [ApplicationId] UNIQUEIDENTIFIER NOT NULL,
    [ProductName]   NVARCHAR (255)   NOT NULL,
    [Edition]       NVARCHAR (255)   NOT NULL,
    [KmsId]         UNIQUEIDENTIFIER NULL,
    [VersionName]   NVARCHAR (255)   NOT NULL,
    [ProductFamily] NVARCHAR (6)     NOT NULL,
    [SupportsAd]    INT              NOT NULL
);


GO
PRINT N'Creating PK_ProductMapping...';


GO
ALTER TABLE [base].[ProductMapping]
    ADD CONSTRAINT [PK_ProductMapping] PRIMARY KEY NONCLUSTERED ([ActConfigId] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);


GO
PRINT N'Creating [base].[VolumeApplication]...';


GO
CREATE TABLE [base].[VolumeApplication] (
    [ApplicationId]   UNIQUEIDENTIFIER              NOT NULL,
    [ApplicationName] [dbo].[VolumeApplicationName] NOT NULL,
    [OnlineHelpUri]   NVARCHAR (512)                NULL
);


GO
PRINT N'Creating PK_VolumeApplication...';


GO
ALTER TABLE [base].[VolumeApplication]
    ADD CONSTRAINT [PK_VolumeApplication] PRIMARY KEY CLUSTERED ([ApplicationId] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);


GO
PRINT N'Creating [base].[VolumeApplication].[IX_VolumeApplication_ApplicationName]...';


GO
CREATE NONCLUSTERED INDEX [IX_VolumeApplication_ApplicationName]
    ON [base].[VolumeApplication]([ApplicationName] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF, ONLINE = OFF, MAXDOP = 0);


GO
PRINT N'Creating [base].[VolumeClient]...';


GO
CREATE TABLE [base].[VolumeClient] (
    [FullyQualifiedDomainName] [dbo].[FullyQualifiedDomainName] NOT NULL,
    [DomainWorkgroupName]      [dbo].[FullyQualifiedDomainName] NULL,
    [NetworkType]              INT                              NULL,
    [OSEdition]                [dbo].[VolumeApplicationName]    NULL,
    [OSVersion]                [dbo].[VersionString]            NULL,
    [IsKmsHost]                BIT                              NOT NULL,
    [RowVer]                   TIMESTAMP                        NOT NULL
);


GO
PRINT N'Creating PK_VolumeClient...';


GO
ALTER TABLE [base].[VolumeClient]
    ADD CONSTRAINT [PK_VolumeClient] PRIMARY KEY NONCLUSTERED ([FullyQualifiedDomainName] ASC) WITH (ALLOW_PAGE_LOCKS = ON, ALLOW_ROW_LOCKS = ON, PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, STATISTICS_NORECOMPUTE = OFF);


GO
PRINT N'Creating [load].[ActiveProduct]...';


GO
CREATE TABLE [load].[ActiveProduct] (
    [FullyQualifiedDomainName] [dbo].[FullyQualifiedDomainName] NOT NULL,
    [ProductName]              [dbo].[VolumeApplicationName]    NULL,
    [ProductDescription]       [dbo].[VolumeApplicationName]    NULL,
    [ProductVersion]           [dbo].[VersionString]            NULL,
    [LicenseFamily]            [dbo].[ProductEdition]           NULL,
    [ApplicationId]            NVARCHAR (39)                    NOT NULL,
    [InstallationId]           [dbo].[ProductInstallationId]    NULL,
    [ProductKeyId]             [dbo].[ProductKeyId]             NULL,
    [ProductKeyType]           [dbo].[ProductKeyType]           NOT NULL,
    [PartialProductKey]        NVARCHAR (5)                     NULL,
    [Sku]                      NVARCHAR (39)                    NOT NULL,
    [LicenseStatus]            INT                              NOT NULL,
    [LicenseStatusReason]      INT                              NOT NULL,
    [GraceExpirationDate]      DATETIME                         NULL,
    [ActionsAllowed]           INT                              NOT NULL,
    [GenuineStatus]            INT                              NOT NULL,
    [LicenseStatusLastUpdated] DATETIME                         NULL,
    [CMID]                     NVARCHAR (39)                    NULL,
    [KmsHost]                  [dbo].[FullyQualifiedDomainName] NULL,
    [KmsPort]                  INT                              NULL,
    [LastActionStatus]         [dbo].[LastActionStatusMsg]      NOT NULL,
    [LastErrorCode]            INT                              NOT NULL,
    [LastUpdated]              DATETIME                         NULL,
    [ExportGuid]               NVARCHAR (39)                    NULL,
    [ConfirmationId]           [dbo].[ProductConfirmationId]    NULL,
    [SoftwareProvider]         INT                              NOT NULL,
    [VLActivationType]         INT                              NOT NULL,
    [VLActivationTypeEnabled]  INT                              NOT NULL,
    [AdActivationObjectName]   [dbo].[AdObjectName]             NULL,
    [AdActivationObjectDN]     [dbo].[AdObjectDn]               NULL,
    [AdActivationCsvlkPid]     [dbo].[ProductKeyId]             NULL,
    [AdActivationCsvlkSkuId]   UNIQUEIDENTIFIER                 NULL
);


GO
PRINT N'Creating [load].[ActiveProductWithoutPii]...';


GO
CREATE TABLE [load].[ActiveProductWithoutPii] (
    [LastActionStatus] [dbo].[LastActionStatusMsg] NOT NULL,
    [LastErrorCode]    INT                         NOT NULL,
    [LastUpdated]      DATETIME                    NULL,
    [ExportGuid]       NVARCHAR (39)               NULL
);


GO
PRINT N'Creating [load].[AvailableProduct]...';


GO
CREATE TABLE [load].[AvailableProduct] (
    [FullyQualifiedDomainName] [dbo].[FullyQualifiedDomainName] NOT NULL,
    [ApplicationId]            NVARCHAR (39)                    NOT NULL,
    [Sku]                      NVARCHAR (39)                    NOT NULL,
    [SoftwareProvider]         INT                              NOT NULL
);


GO
PRINT N'Creating [load].[ConfirmationId]...';


GO
CREATE TABLE [load].[ConfirmationId] (
    [InstallationId] [dbo].[ProductInstallationId] NOT NULL,
    [ConfirmationId] [dbo].[ProductConfirmationId] NOT NULL,
    [ExportGuid]     UNIQUEIDENTIFIER              NOT NULL
);


GO
PRINT N'Creating [load].[ProductsToDelete]...';


GO
CREATE TABLE [load].[ProductsToDelete] (
    [FullyQualifiedDomainName] [dbo].[FullyQualifiedDomainName] NOT NULL,
    [ApplicationId]            UNIQUEIDENTIFIER                 NOT NULL,
    [Sku]                      UNIQUEIDENTIFIER                 NOT NULL
);


GO
PRINT N'Creating [load].[VolumeClient]...';


GO
CREATE TABLE [load].[VolumeClient] (
    [FullyQualifiedDomainName] [dbo].[FullyQualifiedDomainName] NOT NULL,
    [DomainWorkgroupName]      [dbo].[FullyQualifiedDomainName] NULL,
    [NetworkType]              INT                              NULL,
    [OSEdition]                [dbo].[VolumeApplicationName]    NULL,
    [OSVersion]                [dbo].[VersionString]            NULL,
    [IsKmsHost]                BIT                              NOT NULL
);


GO
PRINT N'Creating On column: LastErrorCode...';


GO
ALTER TABLE [base].[ActiveProduct]
    ADD DEFAULT 0 FOR [LastErrorCode];


GO
PRINT N'Creating On column: UserRemarks...';


GO
ALTER TABLE [base].[ProductKey]
    ADD DEFAULT '' FOR [UserRemarks];


GO
PRINT N'Creating On column: RemainingActivations...';


GO
ALTER TABLE [base].[ProductKey]
    ADD DEFAULT -1 FOR [RemainingActivations];


GO
PRINT N'Creating On column: LastErrorCode...';


GO
ALTER TABLE [base].[ProductKey]
    ADD DEFAULT 0 FOR [LastErrorCode];


GO
PRINT N'Creating On column: LastErrorCode...';


GO
ALTER TABLE [load].[ActiveProduct]
    ADD DEFAULT 0 FOR [LastErrorCode];


GO
PRINT N'Creating On column: LastErrorCode...';


GO
ALTER TABLE [load].[ActiveProductWithoutPii]
    ADD DEFAULT 0 FOR [LastErrorCode];


GO
PRINT N'Creating FK_ActiveProduct_AvailableProduct...';


GO
ALTER TABLE [base].[ActiveProduct] WITH NOCHECK
    ADD CONSTRAINT [FK_ActiveProduct_AvailableProduct] FOREIGN KEY ([FullyQualifiedDomainName], [ApplicationId], [Sku]) REFERENCES [base].[AvailableProduct] ([FullyQualifiedDomainName], [ApplicationId], [Sku]) ON DELETE CASCADE ON UPDATE CASCADE;


GO
PRINT N'Creating FK_Available_VolumeApplication...';


GO
ALTER TABLE [base].[ActiveProduct] WITH NOCHECK
    ADD CONSTRAINT [FK_Available_VolumeApplication] FOREIGN KEY ([ApplicationId]) REFERENCES [base].[VolumeApplication] ([ApplicationId]) ON DELETE NO ACTION ON UPDATE NO ACTION;


GO
PRINT N'Creating FK_AvailableProduct_VolumeClient...';


GO
ALTER TABLE [base].[AvailableProduct] WITH NOCHECK
    ADD CONSTRAINT [FK_AvailableProduct_VolumeClient] FOREIGN KEY ([FullyQualifiedDomainName]) REFERENCES [base].[VolumeClient] ([FullyQualifiedDomainName]) ON DELETE CASCADE ON UPDATE CASCADE;


GO
PRINT N'Creating FK_ProductMapping_VolumeApplication...';


GO
ALTER TABLE [base].[ProductMapping] WITH NOCHECK
    ADD CONSTRAINT [FK_ProductMapping_VolumeApplication] FOREIGN KEY ([ApplicationId]) REFERENCES [base].[VolumeApplication] ([ApplicationId]) ON DELETE CASCADE ON UPDATE CASCADE;


GO
PRINT N'Creating [api].[DeleteGvlk]...';


GO
CREATE PROCEDURE [api].[DeleteGvlk]
	@keyValue [dbo].[ProductKey] 
AS
BEGIN
	DELETE FROM [base].[GVLK]
	WHERE
		KeyValue = @keyValue
END
GO
PRINT N'Creating [api].[DeleteProduct]...';


GO
CREATE PROCEDURE [api].[DeleteProduct]
	@FullyQualifiedDomainName [dbo].[FullyQualifiedDomainName],
	@AppId uniqueidentifier,
	@Sku uniqueidentifier
AS
BEGIN
	DELETE FROM [base].[AvailableProduct]
	WHERE
		FullyQualifiedDomainName = @FullyQualifiedDomainName
		AND ApplicationId = @AppId
		AND Sku = @Sku
END
GO
PRINT N'Creating [api].[DeleteProductKey]...';


GO
CREATE PROCEDURE [api].[DeleteProductKey]
	@keyValue [dbo].[ProductKey]
AS
BEGIN
	DELETE FROM [base].[ProductKey]
	WHERE
		KeyValue = @keyValue
END
GO
PRINT N'Creating [api].[DeleteVolumeClient]...';


GO
CREATE PROCEDURE [api].[DeleteVolumeClient]
	@FullyQualifiedDomainName [dbo].[FullyQualifiedDomainName]
AS
BEGIN
	DELETE FROM [base].[VolumeClient]
	WHERE
		FullyQualifiedDomainName = @FullyQualifiedDomainName
END
GO
PRINT N'Creating [api].[FlushClientProductsOnProvider]...';


GO
CREATE PROCEDURE [api].[FlushClientProductsOnProvider]
	@FullyQualifiedDomainName [dbo].[FullyQualifiedDomainName],
	@SoftwareProvider int
AS
BEGIN
	DELETE FROM [base].[AvailableProduct]
	WHERE
		FullyQualifiedDomainName = @FullyQualifiedDomainName
		AND SoftwareProvider = @SoftwareProvider
END
GO
PRINT N'Creating [api].[ReapDefunctMachines]...';


GO
CREATE PROCEDURE [api].[ReapDefunctMachines]
AS
BEGIN

	-- Delete the VolumeClient with the specified FullyQualifiedDomainName
	-- if and only if it has no products associated with it.

	DELETE
	FROM [base].[VolumeClient]
	FROM [base].[VolumeClient] vc LEFT JOIN [base].[ActiveProduct] ap
	ON (vc.FullyQualifiedDomainName = ap.FullyQualifiedDomainName)
	WHERE ap.FullyQualifiedDomainName IS NULL


	-- Delete cached CIDs that don't have a parent VolumeClient anymore.
	DELETE
	FROM [base].[CachedConfirmationId]
	FROM [base].[CachedConfirmationId] cids LEFT JOIN [base].[VolumeClient] vc
	ON (cids.FullyQualifiedDomainName = vc.FullyQualifiedDomainName)
	WHERE vc.FullyQualifiedDomainName IS NULL
END
GO
PRINT N'Creating [dbo].[PurgeVamtProducts]...';


GO
CREATE PROCEDURE [dbo].[PurgeVamtProducts]
AS
BEGIN
	SET TRANSACTION ISOLATION LEVEL SERIALIZABLE

	BEGIN TRANSACTION
		
		-- Cascades to AvailableProduct and ActiveProduct
		DELETE FROM [base].[VolumeClient]

		DELETE FROM [base].[CachedConfirmationId]

	COMMIT TRANSACTION
END
GO
PRINT N'Creating [dbo].[GetMinSupportedVamtRuntime]...';


GO
CREATE FUNCTION [dbo].[GetMinSupportedVamtRuntime]
( )
RETURNS NVARCHAR (43)
WITH EXECUTE AS SELF
AS
BEGIN

    DECLARE @result nvarchar(43)
	
    SELECT @result = CONVERT(nvarchar, value)
    FROM sys.extended_properties
    WHERE class = 0
    AND name = 'VAMT Min Runtime Supported'
    
    RETURN @result

END
GO
PRINT N'Creating [dbo].[GetVamtSchemaVersion]...';


GO
CREATE FUNCTION [dbo].[GetVamtSchemaVersion]
( )
RETURNS NVARCHAR (43)
WITH EXECUTE AS SELF
AS
BEGIN

    DECLARE @result nvarchar(43)
	
    SELECT @result = CONVERT(nvarchar, value)
    FROM sys.extended_properties
    WHERE class = 0
    AND name = 'VAMT DB Schema Version'
    
    RETURN @result

END
GO
PRINT N'Creating [api].[AppliedServiceDataFiles]...';


GO
CREATE VIEW [api].[AppliedServiceDataFiles]
	AS SELECT ServiceDataFileId FROM [base].[AppliedServiceDataFiles]
GO
PRINT N'Creating [api].[AvailableProduct]...';


GO
CREATE VIEW [api].[AvailableProduct]
	AS SELECT 
		app.ApplicationName,
		app.ApplicationId,
		FullyQualifiedDomainName,
		Sku,
		SoftwareProvider
	FROM
		[base].[AvailableProduct] avail
		JOIN [base].[VolumeApplication] app ON avail.ApplicationId = app.ApplicationId
GO
PRINT N'Creating [api].[CachedConfirmationId]...';


GO
CREATE VIEW [api].[CachedConfirmationId]
	AS SELECT 
	InstallationId,
	ConfirmationId,
	FullyQualifiedDomainName,
	ApplicationId,
	Sku
	FROM [base].[CachedConfirmationId]
GO
PRINT N'Creating [api].[GenuineStatusText]...';


GO
CREATE VIEW [api].[GenuineStatusText]
	AS SELECT
		GenuineStatus,
		ResourceLanguage,
		GenuineStatusText
	FROM [base].[GenuineStatusText]
GO
PRINT N'Creating [api].[GVLK]...';


GO
CREATE VIEW api.[GVLK]
	AS SELECT 
		KeyDescription,		
		KeyId,
		KeyValue,
		SupportedEditions,
		SupportedSKU
	FROM [base].[GVLK]
GO
PRINT N'Creating [api].[LicenseStatusText]...';


GO
CREATE VIEW [api].[LicenseStatusText]
	AS SELECT
		LicenseStatus,
		ResourceLanguage,
		LicenseStatusText
	FROM [base].[LicenseStatusText]
GO
PRINT N'Creating [api].[Product]...';


GO
CREATE VIEW [api].[Product]
	AS SELECT
		ActionsAllowed,
		ApplicationName,
		active.ApplicationId,
		CMID,
		ConfirmationId,
		ExportGuid,
		active.FullyQualifiedDomainName,
		active.GenuineStatus,
		GraceExpirationDate,
		active.InstallationId,
		KmsHost,
		KmsPort,
		LastActionStatus,
	    LastErrorCode,
		LastUpdated,
		LicenseFamily,
		active.LicenseStatus,
		LicenseStatusLastUpdated,
		LicenseStatusReason,
		PartialProductKey,
		ProductDescription,
		ProductKeyId,
		ProductName,
		ProductKeyType,
		ProductVersion,
		RowVer,
		active.Sku,
		KeyTypeName,
		LicenseStatusText,
		GenuineStatusText,
		gst.ResourceLanguage,
		SoftwareProvider,
		VLActivationType,
		VLActivationTypeEnabled,
		AdActivationObjectName,
		AdActivationObjectDN,
		AdActivationCsvlkPid,
		AdActivationCsvlkSkuId 
	FROM 
		([base].[ActiveProduct] active LEFT OUTER JOIN [base].[ProductKeyTypeName] tn ON active.ProductKeyType = tn.KeyType)
		JOIN [base].[VolumeApplication] app ON active.ApplicationId = app.ApplicationId
		JOIN [base].[LicenseStatusText] lst ON active.LicenseStatus = lst.LicenseStatus
		JOIN [base].[GenuineStatusText] gst ON active.GenuineStatus = gst.GenuineStatus
	WHERE
		gst.ResourceLanguage = lst.ResourceLanguage
GO
PRINT N'Creating [api].[ProductKey]...';


GO
CREATE VIEW [api].[ProductKey]
	AS SELECT 
		KeyDescription,		
		KeyId,
		pk.KeyType,
		KeyValue,
		LastUpdate,
		LastErrorCode,
		RemainingActivations,
		RowVer,
		SupportedEditions,
		SupportedSKU,
	    UserRemarks,
		KeyTypeName
	FROM [base].[ProductKey] pk JOIN [base].[ProductKeyTypeName] tn
	ON pk.KeyType = tn.KeyType
GO
PRINT N'Creating [api].[ProductKeyTypeName]...';


GO
CREATE VIEW [api].[ProductKeyTypeName]
	AS SELECT 
	KeyType,
	KeyTypeName
	FROM [base].[ProductKeyTypeName]
GO
PRINT N'Creating [api].[ProductMapping]...';


GO
CREATE VIEW [api].[ProductMapping]
	AS SELECT
		ActConfigId,
		map.ApplicationId,
		ApplicationName,
		ProductName,
		Edition,
		KmsId,
		VersionName,
		ProductFamily,
		SupportsAd
	FROM [base].[ProductMapping] map
		JOIN [base].[VolumeApplication] app ON map.ApplicationId = app.ApplicationId
GO
PRINT N'Creating [api].[VolumeApplication]...';


GO
CREATE VIEW [api].[VolumeApplication]
	AS SELECT ApplicationId, ApplicationName, OnlineHelpUri
	FROM [base].[VolumeApplication]
GO
PRINT N'Creating [api].[VolumeClient]...';


GO
CREATE VIEW [api].[VolumeClient]
	AS
	SELECT
		FullyQualifiedDomainName,
		DomainWorkgroupName,
		IsKmsHost,		
		NetworkType,		
		OSEdition,
		OSVersion,
		RowVer
	FROM [base].[VolumeClient]
GO
PRINT N'Creating [load].[ProcessImportData]...';


GO
CREATE PROCEDURE [load].[ProcessImportData]
AS
BEGIN
	SET NOCOUNT ON
	
	-- Import unique VolumeClients
	MERGE [base].[VolumeClient] clients
		USING (
			SELECT * FROM
				(SELECT ROW_NUMBER() OVER ( PARTITION BY FullyQualifiedDomainName ORDER BY FullyQualifiedDomainName) AS rowNumber,
					FullyQualifiedDomainName,
					DomainWorkgroupName,
					IsKmsHost,
					NetworkType,
					OSEdition,
					OSVersion
					FROM [load].[VolumeClient]) AS Records
			WHERE rowNumber = 1) AS ld
		ON
			clients.FullyQualifiedDomainName = ld.FullyQualifiedDomainName
		WHEN MATCHED
			THEN UPDATE SET
				DomainWorkgroupName = ld.DomainWorkgroupName,
				IsKmsHost = ld.IsKmsHost,
				NetworkType = ld.NetworkType,
				OSEdition = ld.OSEdition,
				OSVersion = ld.OSVersion
		WHEN NOT MATCHED
			THEN INSERT (FullyQualifiedDomainName, DomainWorkgroupName, IsKmsHost, NetworkType, OSEdition, OSVersion)
					VALUES(ld.FullyQualifiedDomainName, ld.DomainWorkgroupName, ld.IsKmsHost, ld.NetworkType, ld.OSEdition, ld.OSVersion);


	-- Import unique AvailableProducts
	MERGE [base].[AvailableProduct]
		USING (
			SELECT * FROM
				(SELECT ROW_NUMBER() OVER ( PARTITION BY FullyQualifiedDomainName, ApplicationId, Sku ORDER BY FullyQualifiedDomainName, ApplicationId, Sku) AS rowNumber,
					FullyQualifiedDomainName,
					ApplicationId,
					Sku,
					SoftwareProvider
					FROM [load].[AvailableProduct]) AS Records
			WHERE rowNumber = 1) AS loadAvailableProduct
		ON
			availableProduct.FullyQualifiedDomainName = loadAvailableProduct.FullyQualifiedDomainName 
			AND availableProduct.ApplicationId = loadAvailableProduct.ApplicationId
			AND availableProduct.Sku = loadAvailableProduct.Sku
			AND availableProduct.SoftwareProvider = loadAvailableProduct.SoftwareProvider
		WHEN NOT MATCHED
			THEN INSERT (FullyQualifiedDomainName, ApplicationId, Sku, SoftwareProvider)
					VALUES(loadAvailableProduct.FullyQualifiedDomainName, loadAvailableProduct.ApplicationId, loadAvailableProduct.Sku, loadAvailableProduct.SoftwareProvider);

	-- Import unique products
	MERGE [base].[ActiveProduct] ap
		USING (
			SELECT * FROM
				(SELECT ROW_NUMBER() OVER ( PARTITION BY FullyQualifiedDomainName, ApplicationId, Sku ORDER BY FullyQualifiedDomainName, ApplicationId, Sku) AS rowNumber,
					ActionsAllowed,
					ApplicationId,
					CMID,
					FullyQualifiedDomainName,
					GenuineStatus,
					GraceExpirationDate,
					InstallationId,
					ConfirmationId,
					KmsHost,
					KmsPort,
					LastActionStatus,
					LastErrorCode,
					LastUpdated,
					LicenseFamily,
					LicenseStatus,
					LicenseStatusLastUpdated,
					LicenseStatusReason,
					PartialProductKey,
					ProductDescription,
					ProductKeyId,
					ProductName,
					ProductKeyType,
					ProductVersion,
					Sku,
					ExportGuid,
					SoftwareProvider,
					VLActivationType,
					VLActivationTypeEnabled,
					AdActivationObjectName,
					AdActivationObjectDN,
					AdActivationCsvlkPid,
					AdActivationCsvlkSkuId 
					FROM [load].[ActiveProduct]) AS Records
				WHERE rowNumber = 1) AS loadProducts
		ON
			ap.FullyQualifiedDomainName = loadProducts.FullyQualifiedDomainName 
			AND ap.ApplicationId = loadProducts.ApplicationId
			AND ap.Sku = loadProducts.Sku
		WHEN MATCHED
			THEN UPDATE SET
				ActionsAllowed = loadProducts.ActionsAllowed,
				ApplicationId = loadProducts.ApplicationId,
				CMID = loadProducts.CMID,
				FullyQualifiedDomainName = loadProducts.FullyQualifiedDomainName,
				GenuineStatus = loadProducts.GenuineStatus,
				GraceExpirationDate = loadProducts.GraceExpirationDate,
				InstallationId = loadProducts.InstallationId,
				ConfirmationId = loadProducts.ConfirmationId,
				KmsHost = loadProducts.KmsHost,
				KmsPort = loadProducts.KmsPort,
				LastActionStatus = loadProducts.LastActionStatus,
				LastErrorCode = loadProducts.LastErrorCode,
				LastUpdated = loadProducts.LastUpdated,
				LicenseFamily = loadProducts.LicenseFamily,
				LicenseStatus = loadProducts.LicenseStatus,
				LicenseStatusLastUpdated = loadProducts.LicenseStatusLastUpdated,
				LicenseStatusReason = loadProducts.LicenseStatusReason,
				PartialProductKey = loadProducts.PartialProductKey,
				ProductDescription = loadProducts.ProductDescription,
				ProductKeyId = loadProducts.ProductKeyId,
				ProductName = loadProducts.ProductName,
				ProductKeyType = loadProducts.ProductKeyType,
				ProductVersion = loadProducts.ProductVersion,
				Sku = loadProducts.Sku,
				ExportGuid = loadProducts.ExportGuid,
				SoftwareProvider = loadProducts.SoftwareProvider,
				VLActivationType = loadProducts.VLActivationType,
				VLActivationTypeEnabled = loadProducts.VLActivationTypeEnabled,
				AdActivationObjectName = loadProducts.AdActivationObjectName,
				AdActivationObjectDN = loadProducts.AdActivationObjectDN,
				AdActivationCsvlkPid = loadProducts.AdActivationCsvlkPid,
				AdActivationCsvlkSkuId = loadProducts.AdActivationCsvlkSkuId 
		WHEN NOT MATCHED
			THEN INSERT (
					ActionsAllowed,
					ApplicationId,
					CMID,
					FullyQualifiedDomainName,
					GenuineStatus,
					GraceExpirationDate,
					InstallationId,
					ConfirmationId,
					KmsHost,
					KmsPort,
					LastActionStatus,
					LastErrorCode,
					LastUpdated,
					LicenseFamily,
					LicenseStatus,
					LicenseStatusLastUpdated,
					LicenseStatusReason,
					PartialProductKey,
					ProductDescription,
					ProductKeyId,
					ProductName,
					ProductKeyType,
					ProductVersion,
					Sku,
					ExportGuid,
					SoftwareProvider,
					VLActivationType,
					VLActivationTypeEnabled,
					AdActivationObjectName,
					AdActivationObjectDN,
					AdActivationCsvlkPid,
					AdActivationCsvlkSkuId)
				VALUES(
					loadProducts.ActionsAllowed,
					loadProducts.ApplicationId,
					loadProducts.CMID,
					loadProducts.FullyQualifiedDomainName,
					loadProducts.GenuineStatus,
					loadProducts.GraceExpirationDate,
					loadProducts.InstallationId,
					loadProducts.ConfirmationId,
					loadProducts.KmsHost,
					loadProducts.KmsPort,
					loadProducts.LastActionStatus,
					loadProducts.LastErrorCode,
					loadProducts.LastUpdated,
					loadProducts.LicenseFamily,
					loadProducts.LicenseStatus,
					loadProducts.LicenseStatusLastUpdated,
					loadProducts.LicenseStatusReason,
					loadProducts.PartialProductKey,
					loadProducts.ProductDescription,
					loadProducts.ProductKeyId,
					loadProducts.ProductName,
					loadProducts.ProductKeyType,
					loadProducts.ProductVersion,
					loadProducts.Sku,
					loadProducts.ExportGuid,
					loadProducts.SoftwareProvider,
					loadProducts.VLActivationType,
					loadProducts.VLActivationTypeEnabled,
					loadProducts.AdActivationObjectName,
					loadProducts.AdActivationObjectDN,
					loadProducts.AdActivationCsvlkPid,
					loadProducts.AdActivationCsvlkSkuId);

	-- Merge products that didn't have PII. If there are any duplicates, the first one wins.
		MERGE [base].[ActiveProduct] ap
		USING (
			SELECT * FROM
				(SELECT ROW_NUMBER() OVER ( PARTITION BY ExportGuid ORDER BY ExportGuid) AS rowNumber,
					LastActionStatus,
					LastErrorCode,
					LastUpdated,
					ExportGuid
					FROM [load].[ActiveProductWithoutPii]) AS Records
			WHERE rowNumber = 1) AS loadProductWithoutPii
		ON
			ap.ExportGuid = loadProductWithoutPii.ExportGuid
		WHEN MATCHED
			THEN UPDATE SET
				LastActionStatus = loadProductWithoutPii.LastActionStatus,
				LastErrorCode = loadProductWithoutPii.LastErrorCode,
				LastUpdated = loadProductWithoutPii.LastUpdated;

	-- If any PII-less products can't merge, raise error
		IF EXISTS
			(SELECT NULL
			 FROM [load].[ActiveProductWithoutPii]
			 WHERE NOT EXISTS
				(SELECT NULL
				 FROM
					[base].[ActiveProduct]
				 WHERE
					[base].[ActiveProduct].ExportGuid = [load].[ActiveProductWithoutPii].ExportGuid))
			RAISERROR ('VAMT was unable to import the specified file. The file has had sensitive data removed and this instance of VAMT was unable to  match the products in the file with those in the database. Either the file was created by another instance of VAMT, the associated products have been deleted from the database since the file was created, or the file has been corrupted.',
				11,
				1)


	-- Save the cached CIDs from products with PII
		INSERT INTO [api].[CachedConfirmationId]
		(InstallationId, ConfirmationId, FullyQualifiedDomainName, ApplicationId, Sku)
		SELECT 
			InstallationId,
			ConfirmationId,
			FullyQualifiedDomainName,
			ApplicationId,
			Sku
		FROM
			(SELECT 
				InstallationId,
				ConfirmationId,
				FullyQualifiedDomainName,
				ApplicationId,
				Sku
				FROM [load].[ActiveProduct]) AS loadProducts
		WHERE
			NOT loadProducts.InstallationId IS NULL AND
			NOT loadProducts.ConfirmationId IS NULL


	-- Save the cached CIDs from products without PII
		INSERT INTO [api].[CachedConfirmationId]
		(InstallationId, ConfirmationId, FullyQualifiedDomainName, ApplicationId, Sku)
		SELECT 
			InstallationId,
			ConfirmationId,
			FullyQualifiedDomainName,
			ApplicationId,
			Sku
		FROM
			(SELECT 
				c.InstallationId,
				c.ConfirmationId,
				a.FullyQualifiedDomainName,
				a.ApplicationId,
				a.Sku
				FROM [load].[ConfirmationId] c
				JOIN [base].[ActiveProduct] a
				ON 
					c.ExportGuid = a.ExportGuid AND a.ExportGuid IS NOT NULL
				) AS loadCids
		WHERE
			NOT loadCids.InstallationId IS NULL AND
			NOT loadCids.ConfirmationId IS NULL


	-- clear the load tables
		DELETE FROM [load].[ActiveProduct]

		DELETE FROM [load].[ActiveProductWithoutPii]

		DELETE FROM [load].[AvailableProduct]

		DELETE FROM [load].[VolumeClient]

		DELETE FROM [load].[ConfirmationId]

END
GO
PRINT N'Creating [api].[InsertAppliedServiceDataFilesTrigger]...';


GO
CREATE TRIGGER [InsertAppliedServiceDataFilesTrigger] 
ON [api].[AppliedServiceDataFiles]
INSTEAD OF INSERT
AS
BEGIN
	SET NOCOUNT ON

	MERGE [base].[AppliedServiceDataFiles] applied
		USING (SELECT ServiceDataFileId FROM inserted) AS i
		ON
			applied.ServiceDataFileId = i.ServiceDataFileId
		WHEN NOT MATCHED
			THEN INSERT (ServiceDataFileId)
					VALUES(i.ServiceDataFileId);
END
GO
PRINT N'Creating [api].[DeleteAvailableProductTrigger]...';


GO
CREATE TRIGGER [DeleteAvailableProductTrigger] 
ON [api].[AvailableProduct]
INSTEAD OF DELETE
AS
BEGIN
	SET NOCOUNT ON

	DELETE
		FROM [base].[AvailableProduct]
		FROM [base].[AvailableProduct] INNER JOIN deleted
		ON (
			deleted.FullyQualifiedDomainName = [base].[AvailableProduct].[FullyQualifiedDomainName] AND
			deleted.ApplicationId = [base].[AvailableProduct].[ApplicationId] AND
			deleted.Sku = [base].[AvailableProduct].[Sku])
END
GO
PRINT N'Creating [api].[InsertAvailableProductTrigger]...';


GO
CREATE TRIGGER [InsertAvailableProductTrigger] 
ON [api].[AvailableProduct]
INSTEAD OF INSERT
AS
BEGIN
	SET NOCOUNT ON

	-- Create any new volume application ID entries
	MERGE [base].[VolumeApplication] apps
		USING (SELECT ApplicationId, N'Unknown Application' as AppName FROM inserted) AS i
		ON
			apps.ApplicationId = i.ApplicationId
		WHEN NOT MATCHED
			THEN INSERT (ApplicationId, ApplicationName)
					VALUES(i.ApplicationId, i.AppName);

	-- Satisfy VolumeClient contstraint if needed
	MERGE [base].[VolumeClient] clients
		USING (SELECT FullyQualifiedDomainName FROM inserted) AS i
		ON
			clients.FullyQualifiedDomainName = i.FullyQualifiedDomainName
		WHEN NOT MATCHED
			THEN INSERT (FullyQualifiedDomainName, DomainWorkgroupName, NetworkType, OSEdition, OSVersion, IsKmsHost)
					VALUES(i.FullyQualifiedDomainName, NULL, 0, NULL, NULL, 0);

	-- Insert into the base table iff the row is new
	-- Since all 3 cols are part of the primary key, we needn't
	-- update if it exists already.
	MERGE [base].[AvailableProduct] ap
		USING (SELECT
				FullyQualifiedDomainName,
				ApplicationId,
	 			Sku,
				SoftwareProvider
				FROM inserted) AS i
		ON
			ap.FullyQualifiedDomainName = i.FullyQualifiedDomainName AND
			ap.ApplicationId = i.ApplicationId AND
			ap.Sku = i.Sku AND
			ap.SoftwareProvider = i.SoftwareProvider
		WHEN NOT MATCHED
			THEN INSERT (FullyQualifiedDomainName, ApplicationId, Sku, SoftwareProvider)
					VALUES(i.FullyQualifiedDomainName, i.ApplicationId, i.Sku, i.SoftwareProvider);

END
GO
PRINT N'Creating [api].[InsertCachedConfirmationIdTrigger]...';


GO
CREATE TRIGGER [InsertCachedConfirmationIdTrigger] 
ON [api].[CachedConfirmationId]
INSTEAD OF INSERT
AS
BEGIN
	SET NOCOUNT ON

	MERGE [base].[CachedConfirmationId] cids
		USING (SELECT InstallationId, ConfirmationId, FullyQualifiedDomainName, ApplicationId, Sku FROM inserted) AS i
		ON
			cids.FullyQualifiedDomainName = i.FullyQualifiedDomainName AND
			cids.ApplicationId = i.ApplicationId AND
			cids.Sku = i.Sku
		WHEN MATCHED
			THEN UPDATE SET
				cids.InstallationId = i.InstallationId,
				cids.ConfirmationId = i.ConfirmationId
		WHEN NOT MATCHED
			THEN INSERT (InstallationId, ConfirmationId, FullyQualifiedDomainName, ApplicationId, Sku)
					VALUES(i.InstallationId, i.ConfirmationId, i.FullyQualifiedDomainName, i.ApplicationId, i.Sku);


	MERGE [base].[ActiveProduct] ap
	USING (SELECT InstallationId, ConfirmationId, FullyQualifiedDomainName, ApplicationId, Sku FROM inserted) AS i
	ON
		ap.FullyQualifiedDomainName = i.FullyQualifiedDomainName AND
		ap.ApplicationId = i.ApplicationId AND
		ap.Sku = i.SKU AND
		(ap.InstallationId = i.InstallationId OR ap.ConfirmationId IS NULL)
	WHEN MATCHED
		THEN UPDATE SET
			ap.ConfirmationId = i.ConfirmationId;

END
GO
PRINT N'Creating [api].[InsertGenuineStatusText]...';


GO
CREATE TRIGGER [InsertGenuineStatusText] 
ON [api].[GenuineStatusText]
INSTEAD OF INSERT
AS
BEGIN
	SET NOCOUNT ON

	
	MERGE [base].[GenuineStatusText] txt
		USING (SELECT GenuineStatus, ResourceLanguage, GenuineStatusText FROM inserted) AS i
		ON
			txt.GenuineStatus = i.GenuineStatus AND
			txt.ResourceLanguage = i.ResourceLanguage
		WHEN MATCHED
			THEN UPDATE
				SET
					GenuineStatusText = i.GenuineStatusText
		WHEN NOT MATCHED
			THEN INSERT (GenuineStatus, ResourceLanguage, GenuineStatusText)
					VALUES(i.GenuineStatus, i.ResourceLanguage, i.GenuineStatusText);
END
GO
PRINT N'Creating [api].[InsertGVLKTrigger]...';


GO
CREATE TRIGGER [InsertGVLKTrigger] 
ON [api].[GVLK]
INSTEAD OF INSERT
AS
BEGIN
	SET NOCOUNT ON

	MERGE [base].[GVLK] gvlks
		USING (SELECT KeyDescription, KeyId, KeyValue, SupportedEditions, SupportedSKU FROM inserted) AS i
		ON
			gvlks.KeyValue = i.KeyValue
		WHEN MATCHED
			THEN UPDATE SET
				KeyDescription = i.KeyDescription,
				KeyId = i.KeyId,
				SupportedEditions = i.SupportedEditions,
				SupportedSKU = i.SupportedSKU
		WHEN NOT MATCHED
			THEN INSERT (KeyDescription, KeyId, KeyValue, SupportedEditions, SupportedSKU)
					VALUES(i.KeyDescription, i.KeyId, i.KeyValue, i.SupportedEditions, i.SupportedSKU);
END
GO
PRINT N'Creating [api].[InsertLicenseStatusText]...';


GO
CREATE TRIGGER [InsertLicenseStatusText] 
ON [api].[LicenseStatusText]
INSTEAD OF INSERT
AS
BEGIN
	SET NOCOUNT ON

		
	MERGE [base].[LicenseStatusText] txt
		USING (SELECT LicenseStatus, ResourceLanguage, LicenseStatusText FROM inserted) AS i
		ON
			txt.LicenseStatus = i.LicenseStatus AND
			txt.ResourceLanguage = i.ResourceLanguage
		WHEN MATCHED
			THEN UPDATE
				SET
					LicenseStatusText = i.LicenseStatusText
		WHEN NOT MATCHED
			THEN INSERT (LicenseStatus, ResourceLanguage, LicenseStatusText)
					VALUES(i.LicenseStatus, i.ResourceLanguage, i.LicenseStatusText);
END
GO
PRINT N'Creating [api].[DeleteActiveProductTrigger]...';


GO
CREATE TRIGGER [DeleteActiveProductTrigger] 
ON [api].[Product]
INSTEAD OF DELETE
AS
BEGIN
	SET NOCOUNT ON

	DELETE
		FROM [base].[ActiveProduct]
		FROM [base].[ActiveProduct] INNER JOIN deleted
		ON (
			deleted.FullyQualifiedDomainName = [base].[ActiveProduct].[FullyQualifiedDomainName] AND
			deleted.ApplicationId = [base].[ActiveProduct].[ApplicationId] AND
			deleted.Sku = [base].[ActiveProduct].[Sku])
END
GO
PRINT N'Creating [api].[InsertActiveProductTrigger]...';


GO
CREATE TRIGGER [api].[InsertActiveProductTrigger] 
ON [api].[Product]
INSTEAD OF INSERT
AS
BEGIN
	SET NOCOUNT ON

	-- Enforce referential integrity with available products
	-- (NB: trigger on Available Products enforces integrity with VolumeApplications and VolumeClient)
	
		MERGE [api].[AvailableProduct]
		USING (SELECT FullyQualifiedDomainName, ApplicationId, Sku, SoftwareProvider FROM inserted) AS i
		ON
			availableProduct.FullyQualifiedDomainName = i.FullyQualifiedDomainName 
			AND availableProduct.ApplicationId = i.ApplicationId
			AND availableProduct.Sku = i.Sku
			AND availableProduct.SoftwareProvider = i.SoftwareProvider
		WHEN NOT MATCHED
			THEN INSERT (FullyQualifiedDomainName, ApplicationId, Sku, SoftwareProvider)
					VALUES(i.FullyQualifiedDomainName, i.ApplicationId, i.Sku, i.SoftwareProvider);

	-- Save the cached CID if it is present
	-- Trigger on api.CachedConfirmationId will insert only if it doesn't already exist
		INSERT INTO [api].[CachedConfirmationId]
		(InstallationId, ConfirmationId, FullyQualifiedDomainName, ApplicationId, Sku)
		SELECT
			InstallationId, ConfirmationId, FullyQualifiedDomainName, ApplicationId, Sku
		FROM inserted i
		WHERE
			i.InstallationId <> NULL AND
			i.ConfirmationId <> NULL

	-- Insert or update the active product in the base table
		MERGE [base].[ActiveProduct] ap
		USING (SELECT 
				ActionsAllowed,
				ApplicationId,
				CMID,
				FullyQualifiedDomainName,
				GenuineStatus,
				GraceExpirationDate,
				InstallationId,
				ConfirmationId,
				KmsHost,
				KmsPort,
				LastActionStatus,
				LastErrorCode,
				LastUpdated,
				LicenseFamily,
				LicenseStatus,
				LicenseStatusLastUpdated,
				LicenseStatusReason,
				PartialProductKey,
				ProductDescription,
				ProductKeyId,
				ProductName,
				ProductKeyType,
				ProductVersion,
				Sku,
				ExportGuid,
				SoftwareProvider,
				VLActivationType,
				VLActivationTypeEnabled,
				AdActivationObjectName,
				AdActivationObjectDN,
				AdActivationCsvlkPid,
				AdActivationCsvlkSkuId 
	   		   FROM inserted) AS i
		ON
			ap.FullyQualifiedDomainName = i.FullyQualifiedDomainName 
			AND ap.ApplicationId = i.ApplicationId
			AND ap.Sku = i.Sku
		WHEN MATCHED
			THEN UPDATE SET
				ActionsAllowed = i.ActionsAllowed,
				ApplicationId = i.ApplicationId,
				CMID = i.CMID,
				FullyQualifiedDomainName = i.FullyQualifiedDomainName,
				GenuineStatus = i.GenuineStatus,
				GraceExpirationDate = i.GraceExpirationDate,
				InstallationId = i.InstallationId,
				KmsHost = i.KmsHost,
				KmsPort = i.KmsPort,
				LastActionStatus = i.LastActionStatus,
				LastErrorCode = i.LastErrorCode,
				LastUpdated = i.LastUpdated,
				LicenseFamily = i.LicenseFamily,
				LicenseStatus = i.LicenseStatus,
				LicenseStatusLastUpdated = i.LicenseStatusLastUpdated,
				LicenseStatusReason = i.LicenseStatusReason,
				PartialProductKey = i.PartialProductKey,
				ProductDescription = i.ProductDescription,
				ProductKeyId = i.ProductKeyId,
				ProductName = i.ProductName,
				ProductKeyType = i.ProductKeyType,
				ProductVersion = i.ProductVersion,
				Sku = i.Sku,
				ExportGuid = i.ExportGuid,
				SoftwareProvider = i.SoftwareProvider,
				ConfirmationId =
					CASE
						WHEN NOT i.ConfirmationId IS NULL THEN i.ConfirmationId
						ELSE
							(SELECT TOP 1 ConfirmationId
								FROM [base].[CachedConfirmationId] cids
								WHERE 
									(cids.FullyQualifiedDomainName = i.FullyQualifiedDomainName AND
									 cids.ApplicationId = i.ApplicationId AND
									 cids.Sku = i.Sku)
									OR
									 (cids.InstallationId = i.InstallationId AND NOT i.InstallationId IS NULL))
					END,
				VLActivationType = i.VLActivationType,
				VLActivationTypeEnabled = i.VLActivationTypeEnabled,
				AdActivationObjectName = i.AdActivationObjectName,
				AdActivationObjectDN = i.AdActivationObjectDN,
				AdActivationCsvlkPid = i.AdActivationCsvlkPid,
				AdActivationCsvlkSkuId = i.AdActivationCsvlkSkuId 
		WHEN NOT MATCHED
			THEN INSERT (
					ActionsAllowed,
					ApplicationId,
					CMID,
					FullyQualifiedDomainName,
					GenuineStatus,
					GraceExpirationDate,
					InstallationId,
					KmsHost,
					KmsPort,
					LastActionStatus,
					LastErrorCode,
					LastUpdated,
					LicenseFamily,
					LicenseStatus,
					LicenseStatusLastUpdated,
					LicenseStatusReason,
					PartialProductKey,
					ProductDescription,
					ProductKeyId,
					ProductName,
					ProductKeyType,
					ProductVersion,
					Sku,
					ExportGuid,
					SoftwareProvider,
					ConfirmationId,
					VLActivationType,
					VLActivationTypeEnabled,
					AdActivationObjectName,
					AdActivationObjectDN,
					AdActivationCsvlkPid,
					AdActivationCsvlkSkuId)
				VALUES(
					i.ActionsAllowed,
					i.ApplicationId,
					i.CMID,
					i.FullyQualifiedDomainName,
					i.GenuineStatus,
					i.GraceExpirationDate,
					i.InstallationId,
					i.KmsHost,
					i.KmsPort,
					i.LastActionStatus,
					i.LastErrorCode,
					i.LastUpdated,
					i.LicenseFamily,
					i.LicenseStatus,
					i.LicenseStatusLastUpdated,
					i.LicenseStatusReason,
					i.PartialProductKey,
					i.ProductDescription,
					i.ProductKeyId,
					i.ProductName,
					i.ProductKeyType,
					i.ProductVersion,
					i.Sku,
					i.ExportGuid,
					i.SoftwareProvider,
					CASE
						WHEN NOT i.ConfirmationId IS NULL THEN i.ConfirmationId
						ELSE
							(SELECT TOP 1 ConfirmationId
								FROM [base].[CachedConfirmationId] cids
								WHERE 
									(cids.FullyQualifiedDomainName = i.FullyQualifiedDomainName AND
									 cids.ApplicationId = i.ApplicationId AND
									 cids.Sku = i.Sku)
									OR
									 (cids.InstallationId = i.InstallationId AND NOT i.InstallationId IS NULL))
					END,
					i.VLActivationType,
					i.VLActivationTypeEnabled,
					i.AdActivationObjectName,
					i.AdActivationObjectDN,
					i.AdActivationCsvlkPid,
					i.AdActivationCsvlkSkuId);
END
GO
PRINT N'Creating [api].[UpdateActiveProductTrigger]...';


GO
CREATE TRIGGER [UpdateActiveProductTrigger] 
ON [api].[Product]
INSTEAD OF UPDATE
AS
BEGIN
	SET NOCOUNT ON

	if UPDATE([ExportGuid])
	begin
		DECLARE @NewExportGuid uniqueidentifier;

		SELECT @NewExportGuid = ExportGuid FROM inserted;

		UPDATE [base].[ActiveProduct]
		SET
			ExportGuid = @NewExportGuid
		FROM
			[base].[ActiveProduct] ap JOIN inserted i
		ON
			ap.FullyQualifiedDomainName = i.FullyQualifiedDomainName
			AND ap.ApplicationId = i.ApplicationId
			AND ap.Sku = i.Sku
			

	end
	else
	begin
		raiserror(N'May only update ExportGuid', 18, 0)
	end;

END
GO
PRINT N'Creating [api].[InsertProductKeyTrigger]...';


GO
CREATE TRIGGER [InsertProductKeyTrigger] 
ON [api].[ProductKey]
INSTEAD OF INSERT
AS
BEGIN
	SET NOCOUNT ON
	
	MERGE [base].[ProductKey] keys
		USING (SELECT
					KeyValue,
					KeyId,
					KeyType,
					KeyDescription,
					SupportedEditions,
					SupportedSKU,
					UserRemarks,
					RemainingActivations,
					LastUpdate,
					LastErrorCode
				FROM inserted) AS i
		ON
			keys.KeyValue = i.KeyValue
		WHEN MATCHED
			THEN UPDATE SET
				KeyId = i.KeyId,
				KeyType = i.KeyType,
				KeyDescription = i.KeyDescription,
				SupportedEditions = i.SupportedEditions,
				SupportedSKU = i.SupportedSKU,
				UserRemarks = i.UserRemarks,
				RemainingActivations = i.RemainingActivations,
				LastUpdate = i.LastUpdate,
				LastErrorCode = i.LastErrorCode
		WHEN NOT MATCHED
			THEN INSERT (
				KeyValue,
				KeyId,
				KeyType,
				KeyDescription,
				SupportedEditions,
				SupportedSKU,
				UserRemarks,
				RemainingActivations,
				LastUpdate,
				LastErrorCode)
				
				VALUES(
					i.KeyValue,
					i.KeyId,
					i.KeyType,
					i.KeyDescription,
					i.SupportedEditions,
					i.SupportedSKU,
					i.UserRemarks,
					i.RemainingActivations,
					i.LastUpdate,
					i.LastErrorCode);
END
GO
PRINT N'Creating [api].[InsertProductMappingTrigger]...';


GO
CREATE TRIGGER [InsertProductMappingTrigger] 
ON [api].[ProductMapping]
INSTEAD OF INSERT
AS
BEGIN
	SET NOCOUNT ON

	-- Ensure the VolumeApplication Exists.
	MERGE [base].[VolumeApplication] va
	USING (SELECT ApplicationId, ApplicationName FROM inserted) AS i
	ON
		va.ApplicationId = i.ApplicationId
	WHEN NOT MATCHED
			THEN INSERT (ApplicationId, ApplicationName)
					VALUES(i.ApplicationId, i.ApplicationName);


	MERGE [base].[ProductMapping] map
	USING (SELECT ActConfigId, ApplicationId, ProductName, Edition, KmsId, VersionName, ProductFamily, SupportsAd FROM inserted) AS i
	ON
		map.ActConfigId = i.ActConfigId
	WHEN MATCHED
		THEN UPDATE SET
			ProductName = i.ProductName,
			Edition = i.Edition,
			KmsId = i.KmsId,
			VersionName = i.VersionName,
			ProductFamily = i.ProductFamily,
			SupportsAd = i.SupportsAd
	WHEN NOT MATCHED
			THEN INSERT (ActConfigId, ApplicationId, ProductName, Edition, KmsId, VersionName, ProductFamily, SupportsAd)
					VALUES(i.ActConfigId, i.ApplicationId, i.ProductName, i.Edition, i.KmsId, i.VersionName, i.ProductFamily, i.SupportsAd);
END
GO
PRINT N'Creating [api].[InsertVolumeClientTrigger]...';


GO
CREATE TRIGGER [InsertVolumeClientTrigger] 
ON [api].[VolumeClient]
INSTEAD OF INSERT
AS
BEGIN
	SET NOCOUNT ON

	MERGE [base].[VolumeClient] clients
		USING (SELECT FullyQualifiedDomainName, DomainWorkgroupName, IsKmsHost, NetworkType, OSEdition, OSVersion FROM inserted) AS i
		ON
			clients.FullyQualifiedDomainName = i.FullyQualifiedDomainName
		WHEN MATCHED
			THEN UPDATE SET
				DomainWorkgroupName = i.DomainWorkgroupName,
				IsKmsHost = i.IsKmsHost,
				NetworkType = i.NetworkType,
				OSEdition = i.OSEdition,
				OSVersion = i.OSVersion
		WHEN NOT MATCHED
			THEN INSERT (FullyQualifiedDomainName, DomainWorkgroupName, IsKmsHost, NetworkType, OSEdition, OSVersion)
					VALUES(i.FullyQualifiedDomainName, i.DomainWorkgroupName, i.IsKmsHost, i.NetworkType, i.OSEdition, i.OSVersion);

END
GO
-- Refactoring step to update target server with deployed transaction logs
CREATE TABLE  [dbo].[__RefactorLog] (OperationKey UNIQUEIDENTIFIER NOT NULL PRIMARY KEY)
GO
sp_addextendedproperty N'microsoft_database_tools_support', N'refactoring log', N'schema', N'dbo', N'table', N'__RefactorLog'
GO

GO
--Ensure case insensitive accent insensitive collation
ALTER DATABASE [$(DatabaseName)] COLLATE Latin1_General_CI_AI
GO

--Enable snapshot isolation
ALTER DATABASE [$(DatabaseName)] SET READ_COMMITTED_SNAPSHOT ON;
GO

ALTER DATABASE [$(DatabaseName)] SET ALLOW_SNAPSHOT_ISOLATION ON;
GO

--Insert the DB Version
EXEC sp_addextendedproperty @name = N'VAMT DB Schema Version', @value = N'3.0.5.0'
GO

--Change this value when older data access layers can no longer read the database
--In practice, keep this up to date with the released builds
EXEC sp_addextendedproperty @name = N'VAMT Min Runtime Supported', @value = N'3.0.5.0' 
GO

GO
PRINT N'Checking existing data against newly created constraints';


GO
USE [$(DatabaseName)];


GO
ALTER TABLE [base].[ActiveProduct] WITH CHECK CHECK CONSTRAINT [FK_ActiveProduct_AvailableProduct];

ALTER TABLE [base].[ActiveProduct] WITH CHECK CHECK CONSTRAINT [FK_Available_VolumeApplication];

ALTER TABLE [base].[AvailableProduct] WITH CHECK CHECK CONSTRAINT [FK_AvailableProduct_VolumeClient];

ALTER TABLE [base].[ProductMapping] WITH CHECK CHECK CONSTRAINT [FK_ProductMapping_VolumeApplication];


GO
IF EXISTS (SELECT 1
           FROM   [master].[dbo].[sysdatabases]
           WHERE  [name] = N'$(DatabaseName)')
    BEGIN
        DECLARE @VarDecimalSupported AS BIT;
        SELECT @VarDecimalSupported = 0;
        IF ((ServerProperty(N'EngineEdition') = 3)
            AND (((@@microsoftversion / power(2, 24) = 9)
                  AND (@@microsoftversion & 0xffff >= 3024))
                 OR ((@@microsoftversion / power(2, 24) = 10)
                     AND (@@microsoftversion & 0xffff >= 1600))))
            SELECT @VarDecimalSupported = 1;
        IF (@VarDecimalSupported > 0)
            BEGIN
                EXECUTE sp_db_vardecimal_storage_format N'$(DatabaseName)', 'ON';
            END
    END


GO
ALTER DATABASE [$(DatabaseName)]
    SET MULTI_USER 
    WITH ROLLBACK IMMEDIATE;


GO
