CREATE OR REPLACE PACKAGE APPS.XXCM_AF_CREATE_ASSETS_PKG IS
	PROCEDURE XXCM_AF_CREATE_NEW_ASSET (errorcode   OUT VARCHAR2,
 										errbuf      OUT VARCHAR2);
END XXCM_AF_CREATE_ASSETS_PKG;
/