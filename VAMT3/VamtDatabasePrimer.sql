USE [$(DatabaseName)]
GO

--Populate the VolumeApplications table with Windows and Office GUIDs
INSERT INTO [base].[VolumeApplication] (ApplicationId, ApplicationName, OnlineHelpUri) VALUES ('55c92734-d682-4d71-983e-d6ec3f16059f', N'Windows',N'http://go.microsoft.com/fwlink/?LinkId=220306'), ('59a52881-a989-479d-af46-f275c6370663', N'Office',N'http://go.microsoft.com/fwlink/?LinkId=220308');
GO

--Populate the ProductKey table with the builtin GVLKs
-- Windows 7/Server 2008 R2 GVLKs
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('FJ82H-XT6CR-J8D7P-XQJJ2-GPDD4','12345-00170-868-000000-03-1033-6001.0000-1962009','Windows 7 Professional Volume:GVLK','Professional','b92e9980-b9d5-4821-9c94-140f632f6312' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('MRPKT-YTG23-K7D7T-X2JMM-QY7MG','12345-00170-831-005000-03-1033-6001.0000-1962009','Windows 7 ProfessionalN Volume:GVLK','ProfessionalN','54a09a0d-d57b-4c10-8b69-a842d6590ad5' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('33PXH-7Y6KF-2VJC9-XBBR8-HVTHH','12345-00170-918-500000-03-1033-6001.0000-1962009','Windows 7 Enterprise Volume:GVLK','Enterprise','ae2ee509-1b34-41c0-acb7-6d4650168915' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('YDRBP-3D83W-TY26F-D46B2-XCKRJ','12345-00170-940-225000-03-1033-6001.0000-1962009','Windows 7 EnterpriseN Volume:GVLK','EnterpriseN','1cb6d605-11b3-4e14-bb30-da91c8e3983a' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('74YFP-3QFB3-KQT8W-PMXWJ-7M648','12345-00168-001-000128-03-1033-6001.0000-1962009','Server 2008 R2 Datacenter Volume:GVLK','ServerDatacenter','7482e61b-c589-4b7f-8ecc-46d455ac3b87' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('489J6-VHDMP-X63PK-3K798-CPX3Y','12345-00168-001-000107-03-1033-6001.0000-1962009','Server 2008 R2 Enterprise Volume:GVLK','ServerEnterprise','620e2b3d-09e7-42fd-802a-17a13652fe7a' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('GT63C-RJFQ3-4GMB6-BRFB9-CB83V','12345-00168-001-000021-03-1033-6001.0000-1962009','Server 2008 R2 Enterprise IA64 Volume:GVLK','ServerEnterpriseIA64','8a26851c-1c7e-48d3-a687-fbca9b9ac16b' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('YC6KT-GKW9T-YTKYR-T4X34-R7VHC','12345-00168-001-000042-03-1033-6001.0000-1962009','Server 2008 R2 Standard Volume:GVLK','ServerStandard','68531fb9-5511-4989-97be-d11a0f55633f' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('6TPJF-RBVHG-WBW2R-86QPH-6RTM4','12345-00168-001-000063-03-1033-6001.0000-1962009','Server 2008 R2 Web Volume:GVLK','ServerWeb','a78b8bd9-8017-4df5-b86a-09f756affa7c' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('TT8MH-CG224-D3D7Q-498W2-9QCTX','12345-00168-001-000005-03-1033-6001.0000-2042009','Server 2008 R2 Compute Cluster (HPC) Volume:GVLK','ServerHPC','cda18cf3-c196-46ad-b289-60c072869994' );
GO

-- Windows Vista / Server 2008 GVLKs
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('YFKBB-PQJJV-G996G-VWGXY-2V3X8','12345-00142-236-020000-03-1033-6001.0000-1962009','Windows Vista Business - GVLK','Business','4f3d1606-3fea-4c01-be3c-8d671c401e3b' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('HMBQG-8H2RH-C77VX-27R82-VMQBT','12345-00142-236-020010-03-1033-6001.0000-1962009','Windows Vista Business N - GVLK','BusinessN','2c682dc2-8b68-4f63-a165-ae291d4cf138' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('VKK3X-68KWM-X2YGT-QR4M6-4BWMV','12345-00142-236-020020-03-1033-6001.0000-1962009','Windows Vista Enterprise - GVLK','Enterprise','cfd8ff08-c0d7-452b-9f60-ef5c70c32094' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('VTC42-BM838-43QHV-84HX6-XJXKV','12345-00142-430-979800-03-1033-6001.0000-1962009','Windows Vista EnterpriseN GVLK','EnterpriseN','d4f54950-26f2-4fb4-ba21-ffab16afcade' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('RCTX3-KWVHP-BR6TB-RB6DM-6X7HP','12345-00152-082-250000-03-1033-6001.0000-1962009','Windows Server 2008 Compute Cluster GVLK','ServerComputeCluster','7afb1156-2c1d-40fc-b260-aab7442b62fe' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('7M67G-PC374-GR742-YH8V4-TCBY3','12345-00152-082-250044-03-1033-6001.0000-1962009','Windows Server 2008 Datacenter GVLK','ServerDatacenter','68b6e220-cf09-466b-92d3-45cd964b9509' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('22XQ2-VRXRG-P8D42-K34TD-G3QQC','12345-00152-082-250055-03-1033-6001.0000-1962009','Windows Server 2008 DatacenterV GVLK','ServerDatacenterV','fd09ef77-5647-4eff-809c-af2b64659a45' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('YQGMW-MPWTJ-34KDK-48M3W-X4Q6V','12345-00152-082-250088-03-1033-6001.0000-1962009','Windows Server 2008 Enterprise GVLK','ServerEnterprise','c1af4d90-d1bc-44ca-85d4-003ba33db3b9' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('39BXF-X8Q23-P2WWT-38T2F-G3FPG','12345-00152-082-250022-03-1033-6001.0000-1962009','Windows Server 2008 EnterpriseV GVLK','ServerEnterpriseV','8198490a-add0-47b2-b3ba-316b12d647b4' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('4DWFP-JF3DJ-B7DTH-78FJB-PDRHK','12345-00152-082-250066-03-1033-6001.0000-1962009','Windows Server 2008 Itanium GVLK','ServerEnterpriseIA64','01ef176b-3e0d-422a-b4f8-4ea880035e8f' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('TM24T-X9RMF-VWXK6-X8JC9-BFGM2','12345-00152-082-250011-03-1033-6001.0000-1962009','Windows Server 2008 Standard GVLK','ServerStandard','ad2542d4-9154-4c6d-8a44-30f11ee96989' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('W7VD6-7JFBR-RX26B-YKQ3Y-6FFFJ','12345-00152-082-250033-03-1033-6001.0000-1962009','Windows Server 2008 StandardV GVLK','ServerStandardV','2401e3d0-c50a-4b58-87b2-7e794b7d2607' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('WYR28-R7TFJ-3X2YQ-YCY4H-M249D','12345-00152-082-250077-03-1033-6001.0000-1962009','Windows Server 2008 Web GVLK','ServerWeb','ddfa9f7c-f09e-40b9-8c1a-be877a9a7f4b' );
GO

-- Office 14 GVLKs
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('V7Y44-9T38C-R2VJK-666HK-T7DDX','12345-00096-018-000000-03-1033-7600.0000-3432009','RTM_Access_KMS_Client','Access','8ce7e872-188c-4b98-9d90-f8f90b7aad02' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('H62QG-HXVKF-PP4HP-66KMR-CW9BM','12345-00138-001-000000-03-1033-7600.0000-3432009','RTM_Excel_KMS_Client','Excel','cee5d470-6e3b-4fcc-8c2b-d17428568a9f' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('QYYW6-QP4CB-MBV6G-HYMCJ-4T3J4','12345-00138-001-000040-03-1033-7600.0000-3432009','RTM_Groove_KMS_Client','Groove','8947d0b8-c33b-43e1-8c56-9b674c052832' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('K96W8-67RPQ-62T9Y-J8FQJ-BT37T','12345-00138-001-000010-03-1033-7600.0000-3432009','RTM_InfoPath_KMS_Client','InfoPath','ca6b6639-4ad6-40ae-a575-14dee07f6430' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('YBJTT-JG6MD-V9Q7P-DBKXJ-38W9R','12345-00076-001-000000-03-1033-7600.0000-3432009','RTM_Mondo_KMS_Client','Mondo','09ed9640-f020-400a-acd8-d7d867dfd9c2' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('7TC2V-WXF6P-TD7RT-BQRXR-B8K32','12345-00030-005-004100-03-1033-7600.0000-3432009','RTM_Mondo_KMS_Client2','Mondo','ef3d4e49-a53d-4d81-a2b1-2ca6c2556b2c' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('Q4Y4M-RHWJM-PY37F-MTKWH-D3XHX','12345-00056-001-000000-03-1033-7600.0000-3432009','RTM_OneNote_KMS_Client','OneNote','ab586f5c-5256-4632-962f-fefd8b49e6f4' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('7YDC2-CWM8M-RRTJC-8MDVC-X3DWQ','12345-00098-001-000000-03-1033-7600.0000-3432009','RTM_Outlook_KMS_Client','Outlook','ecb7c192-73ab-4ded-acf4-2399b095d0cc' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('RC8FX-88JRY-3PF7C-X8P67-P4VTT','12345-00138-001-000020-03-1033-7600.0000-3432009','RTM_PowerPoint_KMS_Client','PowerPoint','45593b1d-dfb1-4e91-bbfb-2d5d0ce2227a' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('YGX6F-PGV49-PGW3J-9BTGG-VHKC6','12345-00098-001-000020-03-1033-7600.0000-3432009','RTM_ProjectPro_KMS_Client','ProjectPro','df133ff7-bf14-4f95-afe3-7b48e7e331ef' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('4HP3K-88W3F-W2K3D-6677X-F9PGB','12345-00098-001-000010-03-1033-7600.0000-3432009','RTM_ProjectStd_KMS_Client','ProjectStd','5dc7bf61-5ec9-4996-9ccb-df806a2d0efe' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('VYBBJ-TRJPB-QFQRF-QFT4D-H3GVB','12345-00096-018-000010-03-1033-7600.0000-3432009','RTM_ProPlus_KMS_Client','ProPlus','6f327760-8c5c-417c-9b61-836a98287e0c' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('BFK7F-9MYHM-V68C7-DRQ66-83YTP','12345-00138-001-000030-03-1033-7600.0000-3432009','RTM_Publisher_KMS_Client','Publisher','b50c4f75-599b-43e8-8dcd-1081a7967241' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('D6QFG-VBYP2-XQHM7-J97RH-VVRCK','12345-00058-001-000000-03-1033-7600.0000-3432009','RTM_SmallBusBasics_KMS_Client','SmallBusBasics','ea509e87-07a1-4a45-9edc-eba5a39f36af' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('V7QKV-4XVVR-XYV4D-F7DFM-8R6BM','12345-00076-001-000010-03-1033-7600.0000-3432009','RTM_Standard_KMS_Client','Standard','9da2a678-fb6b-4e67-ab84-60dd6a9c819a' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('D9DWC-HPYVV-JGF4P-BTWQB-WX8BJ','12345-00138-001-000050-03-1033-7600.0000-3432009','RTM_VisioPrem_KMS_Client','VisioPrem','92236105-bb67-494f-94c7-7f7a607929bd' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('7MCW8-VRQVK-G677T-PDJCM-Q8TCP','12345-00138-001-000060-03-1033-7600.0000-3432009','RTM_VisioPro_KMS_Client','VisioPro','e558389c-83c3-4b29-adfe-5e4d7f46c358' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('767HD-QGMWX-8QTDB-9G3R2-KHFGJ','12345-00138-001-000070-03-1033-7600.0000-3432009','RTM_VisioStd_KMS_Client','VisioStd','9ed833ff-4f92-4f36-b370-8683a4f13275' );
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('HVHB3-C6FV7-KQX9W-YQG79-CRY7T','12345-00062-001-000000-03-1033-7600.0000-3432009','RTM_Word_KMS_Client','Word','2d0882e7-a4e7-423b-8ccc-70d91e0158b1' );
GO

-- Windows 8 GVLKs
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('NTJQR-RKW42-DMDHB-D8F6T-3V2MF','12345-01283-001-000000-03-1033-7600.0000-1732011','Windows RT Volume:GVLK','Windows RT','631ead72-a8ab-4df8-bbdf-372029989bdd');
INSERT INTO [base].[GVLK] (KeyValue, KeyId, KeyDescription, SupportedEditions, SupportedSKU) VALUES ('NHKTD-YYMG6-H77XH-BWBC8-MR8X9','12345-01279-001-000000-03-1033-7600.0000-1732011','Windows 8 Volume:GVLK','Windows 8','2b9c337f-7a1d-4271-90a3-c6855a2b8a1c');
GO

-- Populate product key type names
INSERT INTO [base].[ProductKeyTypeName] (KeyType, KeyTypeName) VALUES
	(0, N'Unknown'),
	(1, N'Retail'),
	(2, N'OEM SLP'),
	(3, N'OEM COA'),
	(4, N'OEM NON SLP'),
	(5, N'CSVLK'),
	(6, N'GVLK'),
	(7, N'MAK'),
	(8, N'TBEVAL'),
	(9, N'TBTRIAL'),
	(10, N'TBPROMO'),
	(11, N'TBSUB'),
	(12, N'OEM Activation 3.0'),
	(13, N'AVMA');
GO

-- Populate Product Mappings
-- WinNext
INSERT INTO [api].[ProductMapping] (ActConfigId, ApplicationId, ProductName, Edition, KmsId, VersionName, ProductFamily, SupportsAD)
VALUES
('5f94a0bb-d5a0-4081-a685-5819418b2fe0', '55c92734-d682-4d71-983e-d6ec3f16059f', 'Windows 8.1','Client', '5f94a0bb-d5a0-4081-a685-5819418b2fe0', 'Windows 8.1', 'Client', 1),
('6d5f5270-31ac-433e-b90a-39892923c657', '55c92734-d682-4d71-983e-d6ec3f16059f', 'Windows Server 2012 R2','Server', '6d5f5270-31ac-433e-b90a-39892923c657', 'Windows Server 2012 R2', 'Server', 1);

GO
