CREATE OR REPLACE PACKAGE APPS.XXCM_FA_AS_REIT_PKG AS


PROCEDURE XXCM_FA_BAJA_ACTIVOS_PROC (errorcode   OUT VARCHAR2,
                                           errbuf      OUT VARCHAR2);

END;
/