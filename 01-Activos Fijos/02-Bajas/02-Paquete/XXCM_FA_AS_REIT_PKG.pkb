CREATE OR REPLACE PACKAGE BODY APPS.XXCM_FA_AS_REIT_PKG
AS
   /*Procedimiento para imprimir en outpu*/
   PROCEDURE print_out (p_message IN VARCHAR2)
   IS
   BEGIN
      Fnd_File.put_line (Fnd_File.output, p_message);
   EXCEPTION
      WHEN OTHERS
      THEN
         Fnd_File.put_line (Fnd_File.output, SQLERRM);
   END print_out;

   /*Procedimiento para imprimir mensajes en el LOG*/
   PROCEDURE Print_Log (P_Message IN VARCHAR2)
   IS
   BEGIN
      Fnd_File.Put_Line (Fnd_File.LOG, P_Message);
   EXCEPTION
      WHEN OTHERS
      THEN
         Fnd_File.Put_Line (Fnd_File.LOG, SQLERRM);
   END Print_Log;
   
   PROCEDURE XXCM_AF_CALLING_PRC
   IS
      v_request             NUMBER;
      V_message_in_out      VARCHAR2 (200);
      l_user_id             NUMBER;
      l_responsibility_id   NUMBER;
      l_application_id      NUMBER;

      v_msg                 VARCHAR2 (1000);

      PRAGMA AUTONOMOUS_TRANSACTION;
      --
      v_conc_id_return      NUMBER;
      v_error               VARCHAR2 (2000) := NULL;
      v_call_status         BOOLEAN;
      v_rphase              VARCHAR2 (80);
      v_rstatus             VARCHAR2 (80);
      v_dphase              VARCHAR2 (30);
      v_dstatus             VARCHAR2 (30);
      v_error_message       VARCHAR2 (2400);
      p_message_in_out      VARCHAR2 (100);
      wait_for_request      VARCHAR2 (10) := 'Y';
      l_layout              BOOLEAN;
   --
   BEGIN
      EXECUTE IMMEDIATE
         'ALTER SESSION SET NLS_LANGUAGE = ''LATIN AMERICAN SPANISH''';


      l_user_id := fnd_profile.VALUE ('USER_ID');
      l_responsibility_id := fnd_profile.VALUE ('RESP_ID');
      l_application_id := FND_GLOBAL.PROG_APPL_ID;

      print_log ('l_user_id: ' || l_user_id);

      fnd_global.apps_initialize (user_id        => l_user_id,
                                  resp_id        => 20563,
                                  resp_appl_id   => 140);


      BEGIN
         l_layout :=
            FND_REQUEST.ADD_LAYOUT ('OFA',
                                    'XFARB',
                                    'ES',
                                    'MX',
                                    'EXCEL');

         IF l_layout
         THEN
            v_request :=
               FND_REQUEST.SUBMIT_REQUEST ('OFA',               ---APPLICATION
                                           'XFARB',            ---PROGRAM
                                           '',                  ---DESCRIPTION
                                           '',                   ---START_TIME
                                           FALSE);              ---SUB_REQUEST
         END IF;

         COMMIT;

         IF v_request = 0
         THEN
            fnd_message.retrieve (v_error);
            print_log (
               '--------------Error al ejecutar el concurrente' || v_error);
         ELSE
            IF wait_for_request = 'Y'
            THEN
               v_call_status :=
                  apps.fnd_concurrent.wait_for_request (
                     request_id   => v_request,
                     interval     => 5,
                     max_wait     => NULL,
                     phase        => v_rphase,
                     status       => v_rstatus,
                     dev_phase    => v_dphase,
                     dev_status   => v_dstatus,
                     MESSAGE      => p_message_in_out);
            END IF;
         END IF;
         
         IF v_call_status = TRUE THEN
            /*Migrando datos de la tabla de hospedaje a la tabla de historial*/
            INSERT INTO XXCM_FA_RETIREMENTS_HISTORY SELECT * FROM XXCM_FA_REITIRENENTS_ALL;
            /*Limpiando la tabla XXCM_FA_REITIRENENTS_ALL(Tabla de hospedaje)*/
            execute immediate 'TRUNCATE TABLE XXCM_FA_REITIRENENTS_ALL';
            COMMIT;
         END IF;
         
         print_log (
            '--------------request del concurrente de reporte: ' || v_request);
      END;
   END XXCM_AF_CALLING_PRC;
   
   PROCEDURE XXCM_FA_RETIREMENT_ASSET_PROC (
      P_asset_hdr_rec   IN     apps.FA_API_TYPES.asset_hdr_rec_type,
      P_return_status      OUT VARCHAR2,
      P_mesg               OUT VARCHAR2)
   IS
      l_trans_rec          FA_API_TYPES.trans_rec_type;
      l_dist_trans_rec     FA_API_TYPES.trans_rec_type;
      l_asset_hdr_rec      FA_API_TYPES.asset_hdr_rec_type;
      l_asset_retire_rec   FA_API_TYPES.asset_retire_rec_type;
      l_asset_dist_tbl     FA_API_TYPES.asset_dist_tbl_type;
      l_subcomp_tbl        FA_API_TYPES.subcomp_tbl_type;
      l_inv_tbl            FA_API_TYPES.inv_tbl_type;

--      P_return_status      VARCHAR2 (2);
      P_mesg_count         NUMBER;
   --P_mesg               VARCHAR2 (4000);
   BEGIN
      DBMS_OUTPUT.enable (1000000);

      FA_SRVR_MSG.Init_Server_Message;

      -- Get standard who info
      l_asset_hdr_rec := P_asset_hdr_rec;

      SELECT FB.ORIGINAL_COST
        INTO l_asset_retire_rec.cost_retired
        FROM APPS.FA_BOOKS FB
       WHERE     FB.ASSET_ID = l_asset_hdr_rec.asset_id
             AND FB.BOOK_TYPE_CODE = l_asset_hdr_rec.book_type_code
             AND FB.DATE_INEFFECTIVE IS NULL;

      --l_asset_retire_rec.cost_retired        := 4142.95;
      l_asset_retire_rec.calculate_gain_loss := FND_API.G_FALSE;

      FA_RETIREMENT_PUB.do_retirement (
         -- std parameters
         p_api_version         => 1.0,
         p_init_msg_list       => FND_API.G_FALSE,
         p_commit              => FND_API.G_FALSE,
         p_validation_level    => FND_API.G_VALID_LEVEL_FULL,
         p_calling_fn          => NULL,
         x_return_status       => P_return_status,
         x_msg_count           => P_mesg_count,
         x_msg_data            => P_mesg,
         -- api parameters
         px_trans_rec          => l_trans_rec,
         px_dist_trans_rec     => l_dist_trans_rec,
         px_asset_hdr_rec      => l_asset_hdr_rec,
         px_asset_retire_rec   => l_asset_retire_rec,
         p_asset_dist_tbl      => l_asset_dist_tbl,
         p_subcomp_tbl         => l_subcomp_tbl,
         p_inv_tbl             => l_inv_tbl);

      FA_ASSET_DESC_PUB.update_retirement_desc (
         p_api_version             => 1.0,
         p_init_msg_list           => FND_API.G_FALSE,
         p_commit                  => FND_API.G_FALSE,
         p_validation_level        => FND_API.G_VALID_LEVEL_FULL,
         p_calling_fn              => NULL,
         x_return_status           => P_return_status,
         x_msg_count               => P_mesg_count,
         x_msg_data                => P_mesg,
         px_trans_rec              => l_trans_rec,
         px_asset_hdr_rec          => l_asset_hdr_rec,
         px_asset_retire_rec_new   => l_asset_retire_rec);


      --dump messages
      P_mesg_count := fnd_msg_pub.count_msg;

      IF P_mesg_count > 0
      THEN
         P_mesg :=
            CHR (10)
            || SUBSTR (
                  fnd_msg_pub.get (fnd_msg_pub.G_FIRST, fnd_api.G_FALSE),
                  1,
                  250);
         print_log (P_mesg);

         FOR i IN 1 .. (P_mesg_count - 1)
         LOOP
            P_mesg :=
               P_mesg
               || SUBSTR (
                     fnd_msg_pub.get (fnd_msg_pub.G_NEXT, fnd_api.G_FALSE),
                     1,
                     250);
         END LOOP;

         print_log (P_mesg);

         fnd_msg_pub.delete_msg ();
      END IF;

      IF (P_return_status <> FND_API.G_RET_STS_SUCCESS)
      THEN
         print_log ('FAILURE');
         P_return_status := 'E';
      --ROLLBACK;
      ELSE
         print_log ('SUCCESS');
         P_return_status := 'P';
         print_log (
            'RETIREMENT_ID' || TO_CHAR (l_asset_retire_rec.retirement_id));
      END IF;
   EXCEPTION
      WHEN OTHERS
      THEN
         --print_out();
         print_LOG ('Error: ' || SQLERRM);
         print_log (
               'Error_Backtrace...'
            || CHR (10)
            || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE ());
   END XXCM_FA_RETIREMENT_ASSET_PROC;
   
   PROCEDURE XXCM_FA_BAJA_ACTIVOS_PROC (errorcode   OUT VARCHAR2,
                                           errbuf      OUT VARCHAR2)
   IS
   
       /*Variables utilizadas al llamado de la APPI*/
      l_asset_hdr_rec    apps.FA_API_TYPES.asset_hdr_rec_type;
      l_asset_desc_rec   apps.FA_API_TYPES.asset_desc_rec_type;
      v_return_status    VARCHAR2 (1);
      v_mesg             VARCHAR2 (2000);
      
      
       /*Variables para el cursor */
      ass_num            NUMBER;
      ass_book           VARCHAR2 (200);
      ass_tag            VARCHAR2 (200);
      ass_des            VARCHAR2 (200);
      ass_mod            VARCHAR2 (200);
      ass_ser            VARCHAR2 (200);

      L_REQUEST_ID       NUMBER; 
      l_user_id             NUMBER;
      l_responsibility_id   NUMBER;
      l_application_id      NUMBER;

       CURSOR C_ASSET_REITIRENENTS
   IS
      SELECT NUMERO_DE_ACTIVO, LIBRO
        FROM XXCM_FA_REITIRENENTS_ALL
       WHERE estatus = 'N';

   BEGIN 
     /*INSERTAR lo nue NUEVOS VALORES A LA TABLA CUSTOM*/
   INSERT INTO XXCM_FA_REITIRENENTS_ALL
      SELECT xat.NUMERO_DE_ACTIVO,
             xat.LIBRO,
             xat.ETIQUETA,
             SUBSTR (xat.DESCRIPCION, 0, 79),
             xat.MODELO,
             xat.NUMERO_DE_SERIE,
             xat.FECHA_DE_DEPOSITO,
             xat.VALOR_FIJO_1,
             xat.VALOR_FIJO_2,
             af.tag_number,
             af.description,
             af.model_number,
             af.serial_number,
             'N',
             NULL,
             SYSDATE
        FROM xxcm.xxcm_af_actxinv_tmp xat,
             (SELECT asm.tag_number,
                     atl.description,
                     asm.model_number,
                     asm.serial_number,
                     asm.asset_id,
                     b.BOOK_TYPE_CODE
                FROM apps.fa_additions_b asm,
                     apps.FA_books b,
                     apps.fa_additions_tl atl
               WHERE     b.asset_id = asm.asset_id
                     AND b.date_ineffective IS NULL
                     AND asm.asset_id = atl.asset_id
                     AND 'ESA' = atl.LANGUAGE
                     AND atl.asset_id = b.asset_id) af
       WHERE     af.asset_id(+) = XAT.NUMERO_DE_ACTIVO
             AND SUBSTR (xat.VALOR_FIJO_2, -5, 5) = '-Baja'
             AND af.BOOK_TYPE_CODE(+) = xat.libro;

        /*Elimina la informacion almacenada solo para los activo que se daran de baja*/
         delete XXCM.xxcm_af_actxinv_tmp
         where SUBSTR (VALOR_FIJO_2, -5, 5) = '-Baja';

      COMMIT;

      
      --Procesa activos a dar de baja
      OPEN C_ASSET_REITIRENENTS;

      LOOP
         FETCH C_ASSET_REITIRENENTS
         INTO ass_num, ass_book;
         EXIT WHEN C_ASSET_REITIRENENTS%NOTFOUND;

         l_asset_hdr_rec.asset_id := ass_num;
         l_asset_hdr_rec.book_type_code := ass_book;
         l_asset_desc_rec.tag_number := NULL;

            /*llamado del procedimiento para dar de baja el activo*/
            XXCM_FA_RETIREMENT_ASSET_PROC (l_asset_hdr_rec,
                                           v_return_status,
                                           v_mesg);
          
         /*Valida el status que regresa*/                                 
         IF v_return_status = 'P'
         THEN
            /*Si el activo se dio de baja conrrectamente se actualiza el estatus*/        
            UPDATE XXCM_FA_REITIRENENTS_ALL
               SET estatus = 'PB',
                   FECHA_DE_PROCESAMIENTO = SYSDATE,
                   mensaje =
                      DECODE (
                         v_return_status,
                         'P',    'El activo dado de baja '
                              || v_mesg)
             WHERE numero_de_activo = ass_num AND estatus = 'N';

         END IF;

         IF v_return_status = 'E'
         THEN
          /*Si el activo  no se dio de baja conrrectamente se actualiza el estatus y se imprime el motivo*/   
            UPDATE XXCM_FA_REITIRENENTS_ALL
               SET estatus = 'EB',
                   FECHA_DE_PROCESAMIENTO = SYSDATE,
                   mensaje =
                      DECODE (
                         v_return_status,
                         'E',    'El activo no puede ser eliminado por: '
                              || v_mesg)
             WHERE numero_de_activo = ass_num AND estatus = 'N';
         END IF;
      END LOOP;
      
    CLOSE C_ASSET_REITIRENENTS;
    
    XXCM_AF_CALLING_PRC;
    
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         print_log (
            'EXCEPTION ' || SQLCODE || ' ' || SUBSTR (SQLERRM, 1, 100));
         print_log ('Trace: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
   END XXCM_FA_BAJA_ACTIVOS_PROC;
   
END XXCM_FA_AS_REIT_PKG;
/