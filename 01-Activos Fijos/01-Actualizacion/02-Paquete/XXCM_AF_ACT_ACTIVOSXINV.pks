CREATE OR REPLACE PACKAGE APPS.XXCM_AF_ACT_ACTIVOSXINV

IS

   PROCEDURE XXCM_AF_UPDATE_ASSET_PROC (

      P_asset_hdr_rec    IN     apps.FA_API_TYPES.asset_hdr_rec_type,

      P_asset_desc_rec   IN     apps.FA_API_TYPES.asset_desc_rec_type,

      P_return_status       OUT VARCHAR2,

      P_mesg                OUT VARCHAR2);

     

      PROCEDURE XXCM_AF_Act_ActivosXInv_Proc (errorcode   OUT VARCHAR2,

                                           errbuf      OUT VARCHAR2);

END XXCM_AF_ACT_ACTIVOSXINV;
/