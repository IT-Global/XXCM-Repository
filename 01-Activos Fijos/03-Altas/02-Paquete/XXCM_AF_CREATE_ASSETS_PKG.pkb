CREATE OR REPLACE PACKAGE BODY APPS.XXCM_AF_CREATE_ASSETS_PKG
IS
   /*=================================================================
          * Procedure print_out
          * Parameters: p_message Mensaje de impresion
          *=================================================================*/
   PROCEDURE print_out (p_message IN VARCHAR2)
   IS
   BEGIN
      Fnd_File.put_line (Fnd_File.output, p_message);
   --print_log(p_message);
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN;
   END print_out;

   /*=================================================================
    * Procedure print_log
    * Parameters: p_message Mensaje de impresion
    *=================================================================*/
   PROCEDURE print_log (p_message IN VARCHAR2)
   IS
   BEGIN
      Fnd_File.put_line (Fnd_File.LOG, p_message);
   --print_log(p_message);
   EXCEPTION
      WHEN OTHERS
      THEN
         RETURN;
   END print_log;

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
                                    'XXCMFAAE',
                                    'ES',
                                    'MX',
                                    'EXCEL');

         IF l_layout
         THEN
            v_request :=
               FND_REQUEST.SUBMIT_REQUEST ('OFA',               ---APPLICATION
                                           'XXCMFAAE',            ---PROGRAM
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
            
             IF v_call_status = TRUE THEN 
            INSERT INTO XXCM_FA_ASSETS_NEW_HISTORY SELECT * FROM XXCM_FA_ASSETS_NEW;
                         
                         /*Borrar registros procesados*/
                         DELETE XXCM_FA_ASSETS_NEW;
                         COMMIT;
            
            END IF;
            
         END IF;
         
        
         
         print_log (
            '--------------request del concurrente de reporte: ' || v_request);
      END;
   END XXCM_AF_CALLING_PRC;

   PROCEDURE XXCM_AF_CREATE_ASSET_PROC (
      p_asset_desc_rec   IN     FA_API_TYPES.asset_desc_rec_type,
      p_num_asset        IN     NUMBER,
      p_book_type_code   IN     VARCHAR2,
      P_return_status       OUT VARCHAR2,
      P_mesg                OUT VARCHAR2)
   IS
      l_asset_desc_rec           FA_API_TYPES.asset_desc_rec_type;    --*** IN
      --p_num_asset                NUMBER := 933965;
      --p_book_type_code           VARCHAR2 (50) := 'IFRS 043';

      l_trans_rec                FA_API_TYPES.trans_rec_type;
      l_dist_trans_rec           FA_API_TYPES.trans_rec_type;
      l_asset_hdr_rec            FA_API_TYPES.asset_hdr_rec_type;
      l_asset_cat_rec            FA_API_TYPES.asset_cat_rec_type;
      l_asset_type_rec           FA_API_TYPES.asset_type_rec_type;
      l_asset_hierarchy_rec      FA_API_TYPES.asset_hierarchy_rec_type;
      l_asset_fin_rec            FA_API_TYPES.asset_fin_rec_type;
      l_asset_deprn_rec          FA_API_TYPES.asset_deprn_rec_type;
      l_asset_dist_rec           FA_API_TYPES.asset_dist_rec_type;
      l_asset_dist_tbl           FA_API_TYPES.asset_dist_tbl_type;
      l_inv_tbl                  FA_API_TYPES.inv_tbl_type;
      l_inv_rate_tbl             FA_API_TYPES.inv_rate_tbl_type;

      l_return_status            VARCHAR2 (1);
      l_mesg_count               NUMBER;
      l_mesg                     VARCHAR2 (4000);

      l_asset_key_ccid           NUMBER;
      l_asset_category_id        NUMBER;
      l_asset_type               VARCHAR2 (50);
      l_asset_cost               NUMBER;
      l_date_placed_in_service   DATE;
      l_code_combination_id      NUMBER;
      l_location_id              NUMBER;
   BEGIN
      -- desc info
      l_asset_desc_rec := p_asset_desc_rec;

      print_log (
         'INICIA CREACION DE NUEVO ACTIVO ' || l_asset_desc_rec.description);


      FOR CC
         IN (SELECT FAB.ASSET_KEY_CCID AA1,
                    FAB.ASSET_CATEGORY_ID AA2,
                    FAB.ASSET_TYPE AA3,
                    FB.ORIGINAL_COST AA4,
                    FB.DATE_PLACED_IN_SERVICE AA5,
                    GCCK.CODE_COMBINATION_ID AA6,
                    FLK.LOCATION_ID AA7
               FROM APPS.FA_ADDITIONS_B FAB,
                    APPS.FA_ADDITIONS_TL FAT,
                    APPS.FA_BOOKS FB,
                    APPS.FA_DISTRIBUTION_HISTORY FDH,
                    APPS.FA_LOCATIONS_KFV FLK,
                    APPS.GL_CODE_COMBINATIONS_KFV GCCK
              WHERE     FAB.ASSET_ID = p_num_asset
                    AND FAB.ASSET_ID = FAT.ASSET_ID
                    AND FAB.ASSET_ID = FDH.ASSET_ID
                    AND FAB.ASSET_ID = FB.ASSET_ID
                    AND FDH.DATE_INEFFECTIVE IS NULL
                    AND FB.TRANSACTION_HEADER_ID_IN =
                           (SELECT MAX (TRANSACTION_HEADER_ID_IN)
                              FROM APPS.FA_BOOKS FB1
                             WHERE     FB1.ASSET_ID = FB.ASSET_ID
                                   AND FB1.BOOK_TYPE_CODE = FB.BOOK_TYPE_CODE)
                    --AND FB.PERIOD_COUNTER_FULLY_RETIRED IS NULL
                    AND FDH.LOCATION_ID = FLK.LOCATION_ID
                    AND GCCK.CODE_COMBINATION_ID = FDH.CODE_COMBINATION_ID
                    AND FAT.LANGUAGE = USERENV ('LANG')
                    AND FB.BOOK_TYPE_CODE <> 'ACE TAX')
      LOOP
         l_asset_key_ccid := CC.AA1;
         l_asset_category_id := CC.AA2;
         l_asset_type := CC.AA3;
         l_asset_cost := CC.AA4;
         l_date_placed_in_service := CC.AA5;
         l_code_combination_id := CC.AA6;
         l_location_id := CC.AA7;
      END LOOP;


      l_asset_desc_rec.asset_key_ccid := l_asset_key_ccid;

      -- cat info
      l_asset_cat_rec.category_id := l_asset_category_id;

      --type info
      l_asset_type_rec.asset_type := l_asset_type;

      -- fin info
      l_asset_fin_rec.cost := l_asset_cost;
      l_asset_fin_rec.date_placed_in_service := l_date_placed_in_service;
      l_asset_fin_rec.depreciate_flag := 'YES';

      -- deprn info
      l_asset_deprn_rec.bonus_ytd_deprn := 0;
      l_asset_deprn_rec.bonus_deprn_reserve := 0;

      -- book / trans info
      l_asset_hdr_rec.book_type_code := p_book_type_code;

      -- distribution info
      l_asset_dist_rec.units_assigned := 1;
      l_asset_dist_rec.expense_ccid := l_code_combination_id;
      l_asset_dist_rec.location_ccid := l_location_id;
      l_asset_dist_rec.assigned_to := NULL;
      l_asset_dist_rec.transaction_units := l_asset_dist_rec.units_assigned;
      l_asset_dist_tbl (1) := l_asset_dist_rec;

      -- call the api
      fa_addition_pub.do_addition (
         -- std parameters
         p_api_version            => 1.0,
         p_init_msg_list          => FND_API.G_FALSE,
         p_commit                 => FND_API.G_FALSE,
         p_validation_level       => FND_API.G_VALID_LEVEL_FULL,
         p_calling_fn             => NULL,
         x_return_status          => l_return_status,
         x_msg_count              => l_mesg_count,
         x_msg_data               => l_mesg,
         -- api parameters
         px_trans_rec             => l_trans_rec,
         px_dist_trans_rec        => l_dist_trans_rec,
         px_asset_hdr_rec         => l_asset_hdr_rec,
         px_asset_desc_rec        => l_asset_desc_rec,
         px_asset_type_rec        => l_asset_type_rec,
         px_asset_cat_rec         => l_asset_cat_rec,
         px_asset_hierarchy_rec   => l_asset_hierarchy_rec,
         px_asset_fin_rec         => l_asset_fin_rec,
         px_asset_deprn_rec       => l_asset_deprn_rec,
         px_asset_dist_tbl        => l_asset_dist_tbl,
         px_inv_tbl               => l_inv_tbl);

      --dump messages
      l_mesg_count := fnd_msg_pub.count_msg;

      IF l_mesg_count > 0
      THEN
         l_mesg :=
               CHR (10)
            || SUBSTR (
                  fnd_msg_pub.get (fnd_msg_pub.G_FIRST, fnd_api.G_FALSE),
                  1,
                  250);
         print_log (l_mesg);

         FOR i IN 1 .. (l_mesg_count - 1)
         LOOP
            l_mesg :=
                  l_mesg
               || SUBSTR (
                     fnd_msg_pub.get (fnd_msg_pub.G_NEXT, fnd_api.G_FALSE),
                     1,
                     250);
         END LOOP;

         print_log (l_mesg);
         fnd_msg_pub.delete_msg ();
      END IF;

      IF (l_return_status <> FND_API.G_RET_STS_SUCCESS)
      THEN
         print_log ('HUBO UN ERROR AL CREAR EL ACTIVO.');
         P_return_status := 'E';
         P_mesg := l_mesg;
      ELSE
         print_log ('SE CREO EL ACTIVO');
         print_log ('ASSET_ID: ' || TO_CHAR (l_asset_hdr_rec.asset_id));
         print_log ('ASSET_NUMBER: ' || l_asset_desc_rec.asset_number);
         P_return_status := 'P';
         P_mesg :=
            'SE CREO EL ACTIVO NUMERO ' || l_asset_desc_rec.asset_number;
      END IF;
   END XXCM_AF_CREATE_ASSET_PROC;


   PROCEDURE XXCM_AF_CREATE_NEW_ASSET (errorcode   OUT VARCHAR2,
                                       errbuf      OUT VARCHAR2)
   IS
      l_asset_hdr_rec       apps.FA_API_TYPES.asset_hdr_rec_type; --número de activo, descripción y libro
      l_asset_desc_rec      apps.FA_API_TYPES.asset_desc_rec_type; --descripción de acivo
      v_return_status       VARCHAR2 (1);       --retorna el estado del activo
      v_mesg                VARCHAR2 (2000);              --retorna un mensaje

      ass_num               NUMBER;
      ass_book              VARCHAR2 (200);
      ass_tag               VARCHAR2 (200);
      ass_des               VARCHAR2 (200);
      ass_mod               VARCHAR2 (200);
      ass_ser               VARCHAR2 (200);


      ass_tag_rep           VARCHAR2 (200);
      L_REQUEST_ID          NUMBER;                      --AJUSTE MIGUEL ANGEL
      l_user_id             NUMBER;
      l_responsibility_id   NUMBER;
      l_application_id      NUMBER;


      CURSOR C_ASSET_NEWS_ITFZ
      IS
         SELECT NUMERO_DE_ACTIVO,
                LIBRO,
                ETIQUETA,
                DESCRIPCION,
                MODELO,
                NUMERO_DE_SERIE
           FROM XXCM_FA_ASSETS_NEW
          WHERE ESTATUS = 'N';
   BEGIN
      --Inserta los valores de la tabla temporal en la otra tabla temporal
      INSERT INTO XXCM_FA_ASSETS_NEW
         SELECT /*+ ORDERED */
               TEMP.NUMERO_DE_ACTIVO,
                TEMP.LIBRO,
                TEMP.ETIQUETA,
                SUBSTR (TEMP.DESCRIPCION, 0, 79),
                TEMP.MODELO,
                TEMP.NUMERO_DE_SERIE,
                TEMP.FECHA_DE_DEPOSITO,
                TEMP.VALOR_FIJO_1,
                TEMP.VALOR_FIJO_2,
                'N',
                NULL,
                SYSDATE
           FROM xxcm.xxcm_af_actxinv_tmp TEMP
          WHERE TEMP.VALOR_FIJO_2 = 'Etiquetado Individual';

      DELETE XXCM.xxcm_af_actxinv_tmp
       WHERE VALOR_FIJO_2 = 'Etiquetado Individual';

      --print_out ('*************** PROCESA ACTIVOS A CREAR *****************');
      OPEN C_ASSET_NEWS_ITFZ;

      LOOP
         FETCH C_ASSET_NEWS_ITFZ
         INTO ass_num, ass_book, ass_tag, ass_des, ass_mod, ass_ser;

         EXIT WHEN C_ASSET_NEWS_ITFZ%NOTFOUND;

         --         print_out ('Activo a CREAR: ' || ass_des || ' Num: ' || ass_num);

         l_asset_desc_rec.tag_number := ass_tag;
         l_asset_desc_rec.description := ass_des;
         l_asset_desc_rec.model_number := ass_mod;
         l_asset_desc_rec.serial_number := ass_ser;

         XXCM_AF_CREATE_ASSET_PROC (l_asset_desc_rec,
                                    ass_num,
                                    ass_book,
                                    v_return_status,
                                    v_mesg);


         print_out ('ESTATUS api: ' || v_return_status);
         print_out ('Mensaje: ' || v_mesg);

         IF v_return_status = 'P'
         THEN
            /*Si el activo se dio de baja conrrectamente se actualiza el estatus*/
            UPDATE XXCM_FA_ASSETS_NEW
               SET estatus = 'PC',
                   FECHA_DE_PROCESAMIENTO = SYSDATE,
                   mensaje =
                      DECODE (v_return_status,
                              'P', 'El activo se creo ' || v_mesg)
             WHERE numero_de_activo = ass_num AND estatus = 'N';
         END IF;

         IF v_return_status = 'E'
         THEN
            UPDATE XXCM_FA_ASSETS_NEW
               SET estatus = 'EC',
                   FECHA_DE_PROCESAMIENTO = SYSDATE,
                   mensaje =
                      DECODE (
                         v_return_status,
                         'E',    'El activo no puede ser eliminado por: '
                              || v_mesg)
             WHERE numero_de_activo = ass_num AND estatus = 'N';
         END IF;
      END LOOP;

      CLOSE C_ASSET_NEWS_ITFZ;

      XXCM_AF_CALLING_PRC;
   EXCEPTION
      WHEN OTHERS
      THEN
         ROLLBACK;
         print_log (
            'EXCEPTION ' || SQLCODE || ' ' || SUBSTR (SQLERRM, 1, 100));
         print_log ('Trace: ' || DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
   END XXCM_AF_CREATE_NEW_ASSET;
END XXCM_AF_CREATE_ASSETS_PKG;
/