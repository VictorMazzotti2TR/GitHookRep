CREATE OR REPLACE PROCEDURE prc_prorrogacao_automatica IS

  --FLAGS que iram guardar o ID do processo comum e de desmonte
  w_n_IdProcesso          number;
  w_n_IdProcesso_desmonte number;
  w_n_IdPrazo             number;
  w_n_valida_exec         number;
  d_ctrl_interface        date;

  --Periodo adicional Entradas Imp
  v_n_meses_pos_data_nfimp number := 36;
  v_n_meses_pos_correcao   number := 24;
  v_d_ini_periodo_nfimp date := to_date('01/01/2019', 'dd/mm/yyyy');
  v_d_fim_periodo_nfimp date := to_date('31/12/2021', 'dd/mm/yyyy');
  v_d_fim_periodo_nfimp_rf date := to_date('31/12/2022', 'dd/mm/yyyy');---atualização in recof e recofsped
  v_s_obs_nfimp PRORROGACAO_DA.OBSERVACAO%type := 'Inclusão de Prorrogação INSTRUÇÃO NORMATIVA RFB Nº 2019 e 2103';
  v_s_adicional_ativo_nfimp char(1) := 'S';

  --Periodo adicional Entradas Desmonte
  v_n_meses_pos_data_desm number := 36;
  v_d_ini_periodo_desm date := to_date('01/01/2019', 'dd/mm/yyyy');
  v_d_fim_periodo_desm date := to_date('31/12/2021', 'dd/mm/yyyy');
  v_d_fim_periodo_desm_rf date := to_date('31/12/2022', 'dd/mm/yyyy');---atualização in recof e recofsped
  v_s_obs_desm PRORROGACAO_DESMONTE.OBSERVACAO%type := 'Inclusão de Prorrogação INSTRUÇÃO NORMATIVA RFB Nº 2019 e 2103';
  v_s_adicional_ativo_desm char(1) := 'S';
  v_s_ctrl_rpi_desm RF_INTERFACE_PRORROGACAO_CTRL.S_CTRL_RPI_DESM%TYPE;

  --Periodo adicional Entradas Nac
  v_n_meses_pos_data_nfnac number := 36;
  v_d_ini_periodo_nfnac date := to_date('01/01/2019', 'dd/mm/yyyy');
  v_d_fim_periodo_nfnac date := to_date('31/12/2021', 'dd/mm/yyyy');
  v_d_fim_periodo_nfnac_rf date := to_date('31/12/2022', 'dd/mm/yyyy');---atualização in recof e recofsped
  v_s_obs_nfnac PRAZO_PERMANENCIA.S_OBSERVACAO%type := 'Inclusão de Prorrogação INSTRUÇÃO NORMATIVA RFB Nº 2019 e 2103';
  v_s_adicional_ativo_nfnac char(1) := 'S';
  v_n_prorrogado    number;
  w_d_dt_prorrogado date;
  v_n_id_doc_prazo  number;
  v_n_id_nf_entrada_ctrl number;
  v_d_dt_vencimento_ant ITENS_PROCESSO_PRORROGACAO.DT_VENCIMENTO_ANT%type;
  v_d_dt_vencimento_ant_desm ITENS_PROCESSO_PRORROGACAO.DT_VENCIMENTO_ANT%type;
  v_s_tipo_reg PARAMETROS.VALOR_A%TYPE :=  pkg_param.get_parametro_alfa(361);
  v_n_id_processo number;

begin

  begin
    execute immediate 'alter session set optimizer_mode = ''choose''';
  end;
  select decode(v_s_tipo_reg,'RPI','N','S') into v_s_adicional_ativo_nfimp from dual;
  select decode(v_s_tipo_reg,'RPI','N','S') into v_s_adicional_ativo_desm  from dual;
  select decode(v_s_tipo_reg,'RPI','N','S') into v_s_adicional_ativo_nfnac from dual;
  
  begin
    select D_CTRL_IN1904,S_CTRL_RPI_DESM into d_ctrl_interface,v_s_ctrl_rpi_desm from RF_INTERFACE_PRORROGACAO_CTRL;
  exception when no_data_found then
    begin
      --a data inicial é a data de vigência inicial da IN 1904
      INSERT INTO RF_INTERFACE_PRORROGACAO_CTRL
        (D_CTRL_IN1904)
      VALUES
        (TO_DATE('01/08/2019', 'DD/MM/YYYY'))
      returning D_CTRL_IN1904 into d_ctrl_interface;
    end;
  end;
  /* RPI  - ATUALIZA COM DATA VENCIMENTO ANTERIOR ---MESES correções RPI - até 24 MES*/
   if v_s_ctrl_rpi_desm is null and v_s_tipo_reg = 'RPI' then
       
      for cLoop in (select
                           ipp.dt_vencimento_ant,
                           pd.id_prorrogacao_da,
                           oadm.id_item_entrada_di,
                           pd.id_processo
                      from declaracao_importacao di,
                           op_adicao_detalhe_mercadoria oadm,
                           PRORROGACAO_DA pd,
                           ITENS_PROCESSO_PRORROGACAO ipp
                      where 
                         di.nr_declaracao_imp = oadm.nr_declaracao_imp
                        and S_PRORROGA_AUTOMATICO = 'S'
                        and pd.id_item_entrada_di = oadm.id_item_entrada_di
                        and ipp.id_item_entrada_di = oadm.id_item_entrada_di
                        and not exists (select 1
                        from op_adicao_detalhe_mercadoria oadm1
                        where di.nr_declaracao_imp = oadm1.nr_declaracao_imp
                              and oadm1.flag_liberada = 'N')
                        and pd.id_processo = ipp.id_processo
                        and di.dt_desembaraco_date between v_d_ini_periodo_nfimp and v_d_fim_periodo_nfimp -- periodo de emissao de NFs considerado na IN 1960                     
                        and pd.dt_vencimento > add_months(di.dt_desembaraco_date, v_n_meses_pos_correcao) 
                      
                    ) loop     
        
                update PRORROGACAO_DA pd
                   SET pd.dt_vencimento = cLoop.dt_vencimento_ant
                 where pd.id_prorrogacao_da = cLoop.id_prorrogacao_da;
                
                select max(DT_VENCIMENTO_ANT)
                  into v_d_dt_vencimento_ant
                  from ITENS_PROCESSO_PRORROGACAO
                 where Dt_Vencimento_Ant < cLoop.dt_vencimento_ant
                   and ID_ITEM_ENTRADA_DI = cLoop.id_item_entrada_di;
                ---
                update ITENS_PROCESSO_PRORROGACAO
                   set ITENS_PROCESSO_PRORROGACAO.Dt_Vencimento_Ant = v_d_dt_vencimento_ant
                 where ID_ITEM_ENTRADA_DI = cLoop.id_item_entrada_di
                   and id_processo = cLoop.id_processo;
      
      end loop;
    ---desmonte 
    if pkg_param.get_parametro_alfa(274) = 'S'  then
     
      for cLoop in (select  odinr.id_item_nfe_desm_result
                      from ord_desm_item_nfe_resultante odinr,
                           ordem_desmonte_item odi,
                           ordem_desmonte od,
                           ord_desm_item_itens_entrada odiie,
                           op_adicao_detalhe_mercadoria oadm,
                           itens_entrada ie,
                           declaracao_importacao di
                     where  odinr.id_item_nf_entrada_resultante = ie.id_item_nf_entrada
                       and odinr.id_item_desmonte = odi.id_item_desmonte
                       and od.id_desmonte = odi.id_desmonte
                       and odiie.id_desmonte = od.id_desmonte
                       and odiie.id_item_entrada_di_desmontado = oadm.id_item_entrada_di
                       and di.nr_declaracao_imp = oadm.nr_declaracao_imp
                       and not exists (select 1
                        from op_adicao_detalhe_mercadoria oadm1
                        where di.nr_declaracao_imp = oadm1.nr_declaracao_imp
                              and oadm1.flag_liberada = 'N')
                       and ie.prorrogado > 0
                       and FNC_GET_TIPO_ENTRADA(ie.TIPO_ENTRADA, 'RECOF') = 'S'
                       and FNC_GET_TIPO_ENTRADA(ie.TIPO_ENTRADA, 'DESMONTE') = 'S'
                       and FNC_GET_TIPO_ENTRADA(ie.TIPO_ENTRADA, 'PRE_SERIE') = 'N'
                       and exists (select 1 from ITENS_PROC_PRORROG_DESM ippd where ippd.id_item_nfe_desm_result = odinr.id_item_nfe_desm_result) --prorogacao anterior via interface                    
                       and di.dt_desembaraco_date between v_d_ini_periodo_desm and v_d_fim_periodo_desm --periodo da prorrogacao adicional
                       and ie.data_vencimento > add_months(di.dt_desembaraco_date, v_n_meses_pos_correcao)
                   ) loop
                   
             begin
               select pd.id_processo
                 into v_n_id_processo
                 from prorrogacao_desmonte pd
                where pd.id_item_nfe_desm_result =
                      cLoop.id_item_nfe_desm_result
                  and pd.observacao = v_s_obs_desm;
             
               begin
                 select ippd.dt_vencimento_ant
                   into v_d_dt_vencimento_ant_desm
                   from ITENS_PROC_PRORROG_DESM ippd
                  where ippd.id_item_nfe_desm_result =
                        cLoop.id_item_nfe_desm_result
                    and ippd.id_processo = v_n_id_processo;
               
                 update prorrogacao_desmonte pd
                    set pd.dt_vencimento = v_d_dt_vencimento_ant_desm
                  where pd.id_item_nfe_desm_result =
                        cLoop.id_item_nfe_desm_result
                    and pd.id_processo = v_n_id_processo;
               
                 select max(DT_VENCIMENTO_ANT)
                   into v_d_dt_vencimento_ant
                   from ITENS_PROC_PRORROG_DESM
                  where Dt_Vencimento_Ant < v_d_dt_vencimento_ant_desm
                    and ID_ITEM_NFE_DESM_RESULT =
                        cLoop.ID_ITEM_NFE_DESM_RESULT;
                 ---
                 update ITENS_PROC_PRORROG_DESM
                    set ITENS_PROC_PRORROG_DESM.Dt_Vencimento_Ant = v_d_dt_vencimento_ant
                  where ID_ITEM_NFE_DESM_RESULT =
                        cLoop.ID_ITEM_NFE_DESM_RESULT
                    AND ID_PROCESSO = v_n_id_processo;
               exception
                 when no_data_found then
                   null;
               end;
             exception
               when no_data_found then
                 null;
             end;
      end loop;
    end if;
   --nacionais
    for cLoop in (select ine.id_item_nf_entrada,
                         ine.id_nf_entrada,
                         ipn.d_dt_vencimento_ant,
                         ipn.n_id_prazo
                    from PRAZO_PERMANENCIA_ITENS ipn,PRAZO_PERMANENCIA pd ,itens_nf_entrada ine, nf_entrada nfe
                   where ipn.n_id_item_nf_entrada = ine.id_item_nf_entrada
                     and nfe.id_nf_entrada = ine.id_nf_entrada
                     and nfe.flag_liberada = 'S'
                     and pd.n_id_prazo = ipn.n_id_prazo
                     and pd.s_prorroga_automatico = 'S'
                     and nfe.data_emissao between  v_d_ini_periodo_nfnac and v_d_fim_periodo_nfnac -- periodo de emissao de NFs considerado na IN 1960
                       and  ipn.d_dt_vencimento_new > add_months(nfe.data_emissao, v_n_meses_pos_correcao) )
    loop
      
      select max(d_dt_vencimento_ant)
        into v_d_dt_vencimento_ant
        from PRAZO_PERMANENCIA_ITENS ipn
       where ipn.d_dt_vencimento_ant < cLoop.d_dt_vencimento_ant
         and ipn.n_id_item_nf_entrada = cLoop.id_item_nf_entrada;
      
      update PRAZO_PERMANENCIA_ITENS ipn
         set ipn.d_dt_vencimento_new = cLoop.d_dt_vencimento_ant,
             ipn.d_dt_vencimento_ant = v_d_dt_vencimento_ant
       where ipn.n_id_item_nf_entrada = cLoop.id_item_nf_entrada
         and ipn.n_id_prazo = cLoop.n_id_prazo;

    end loop;
  
   update RF_INTERFACE_PRORROGACAO_CTRL set RF_INTERFACE_PRORROGACAO_CTRL.S_CTRL_RPI_DESM = 'S';
  end if;
  ---- 
  /* RF - DESMONTE atualiza com ADD_MONTHS(cLoop.dt_desembaraco_date, v_n_meses_pos_data_desm) --MESES correções RF - desmonte - 36 MESES*/
  if v_s_ctrl_rpi_desm is null and pkg_param.get_parametro_alfa(274) = 'S' and v_s_tipo_reg != 'RPI'  then
      w_n_valida_exec := 0;
      for cLoop in ( select  odinr.id_item_nfe_desm_result,di.dt_desembaraco_date
                      from ord_desm_item_nfe_resultante odinr,
                           ordem_desmonte_item odi,
                           ordem_desmonte od,
                           ord_desm_item_itens_entrada odiie,
                           op_adicao_detalhe_mercadoria oadm,
                           itens_entrada ie,
                           declaracao_importacao di
                         
                     where  odinr.id_item_nf_entrada_resultante = ie.id_item_nf_entrada
                       and odinr.id_item_desmonte = odi.id_item_desmonte
                       and od.id_desmonte = odi.id_desmonte
                       and odiie.id_desmonte = od.id_desmonte
                       and odiie.id_item_entrada_di_desmontado = oadm.id_item_entrada_di
                       and di.nr_declaracao_imp = oadm.nr_declaracao_imp
                       and not exists (select 1
                        from op_adicao_detalhe_mercadoria oadm1
                        where di.nr_declaracao_imp = oadm1.nr_declaracao_imp
                              and oadm1.flag_liberada = 'N')
                       and ie.prorrogado > 0
                       and FNC_GET_TIPO_ENTRADA(ie.TIPO_ENTRADA, 'RECOF') = 'S'
                       and FNC_GET_TIPO_ENTRADA(ie.TIPO_ENTRADA, 'DESMONTE') = 'S'
                       and FNC_GET_TIPO_ENTRADA(ie.TIPO_ENTRADA, 'PRE_SERIE') = 'N'
                       and exists (select 1 from ITENS_PROC_PRORROG_DESM ippd where ippd.id_item_nfe_desm_result = odinr.id_item_nfe_desm_result) --prorogacao anterior via interface                    
                       and di.dt_desembaraco_date between v_d_ini_periodo_desm and v_d_fim_periodo_desm_rf --periodo da prorrogacao adicional
                        and ie.data_vencimento > add_months(di.dt_desembaraco_date, v_n_meses_pos_data_desm)
                   ) loop
                   
               begin
                 select pd.id_processo
                   into v_n_id_processo
                   from prorrogacao_desmonte pd
                  where pd.id_item_nfe_desm_result =
                        cLoop.id_item_nfe_desm_result
                    and pd.observacao = v_s_obs_desm;
                    
                 update prorrogacao_desmonte pd
                    set pd.dt_vencimento = ADD_MONTHS(cLoop.dt_desembaraco_date,
                                                      v_n_meses_pos_data_desm)
                  where pd.id_item_nfe_desm_result =
                        cLoop.id_item_nfe_desm_result
                    and pd.id_processo = v_n_id_processo
                    and pd.ID_ITEM_ENTRADA is null;
               
               exception
                 when no_data_found then
                   null;
               end;
            
      end loop;
       update RF_INTERFACE_PRORROGACAO_CTRL set RF_INTERFACE_PRORROGACAO_CTRL.S_CTRL_RPI_DESM = 'S';
    end if;
  
--                      ======================================================
--                         Início Bloco de Prorrogação Automática - Importados
--                      =====================================================
  -- Cria processo apenas se tiver registro para prorrogar
  w_n_valida_exec := 0;
  -- Select que busca os itens que iram vencer no mês atual que são do tipo RECOF agrupando por DI
  for cLoop in (select pr.id_item_entrada_di,
                       SUM(FNC_GET_SALDO_ENTRADA_BAIXA(IE.ID_ITEM_ENTRADA)) SALDO,
                       pr.dt_vencimento,
                       ie.tipo_entrada
                  from PRORROGACAO_DA pr, itens_entrada ie , entradas e
                 where pr.prorrogado = 0
                   and ie.id_item_entrada_di = pr.id_item_entrada_di
                   and e.id_entrada = ie.id_entrada
                   and not exists (select 1
                                  from op_adicao_detalhe_mercadoria oadm1
                                  where e.doc_origem = oadm1.nr_declaracao_imp
                                        and oadm1.flag_liberada = 'N')
                   and FNC_GET_TIPO_ENTRADA(IE.TIPO_ENTRADA, 'RECOF_IMPORTADO') = 'S'
                   and FNC_GET_TIPO_ENTRADA(IE.TIPO_ENTRADA, 'PRE_SERIE') = 'N'
                   and FNC_GET_TIPO_ENTRADA(IE.TIPO_ENTRADA, 'DESMONTE') = 'N'                   
                   and pr.id_item_entrada is null
                   and ie.data_vencimento between d_ctrl_interface and ADD_MONTHS(trunc(PKG_TR_SYSDATE.FNC_TR_SYSDATE),1) -- range: dt da ultima exec interface mais 1 mes de margem da data atual
                 group by pr.id_item_entrada_di,
                       pr.dt_vencimento,
                       ie.tipo_entrada
                 having SUM(FNC_GET_SALDO_ENTRADA_BAIXA(IE.ID_ITEM_ENTRADA)) > 0
                ) loop

    if w_n_valida_exec = 0 then
      -- Criando o processo de prorrogação
      insert into PROCESSO_PRORROGACAO
        (ID_PROCESSO, DT_SOLICITACAO)
      values
        (SEQ_PROCESSO_PRORROGACAO.nextval, PKG_TR_SYSDATE.FNC_TR_SYSDATE)
      returning ID_PROCESSO into w_n_IdProcesso;

      w_n_valida_exec := 1;

      -- Gravando o LOG da operação realizada
      insert into LOG_PRORROGACAO_DA
        (USUARIO, DT_ALTERACAO, ID_PROCESSO, OBSERVACAO_LOG)
      values
        ('INTERFACE',
         PKG_TR_SYSDATE.FNC_TR_SYSDATE,
         w_n_IdProcesso,
         'Inclusão de Prorrogação Automática via Interface');
    end if;

    -- Alterando a DATA de VENCIMENTO da DA e indicando qual é o ID do processo de prorrogação
    update PRORROGACAO_DA pd
       SET ID_PROCESSO           = w_n_IdProcesso,
           pd.dt_vencimento      = add_months(pd.dt_vencimento,
                                              pkg_param.get_parametro_num(72)),
           pd.observacao         = 'Prorrogação da DA gerado automaticamente via INTERFACE',
           PRORROGADO            = PRORROGADO + 1,
           S_PRORROGA_AUTOMATICO = 'S'
     where ID_ITEM_ENTRADA_DI = cLoop.id_item_entrada_di
       and ID_ITEM_ENTRADA is null;
    ----
    insert into ITENS_PROCESSO_PRORROGACAO
      (ID_PROCESSO, ID_ITEM_ENTRADA_DI, SALDO, DT_VENCIMENTO_ANT)
    values
      (w_n_IdProcesso,
       cLoop.id_item_entrada_di,
       cLoop.SALDO,
       cLoop.dt_vencimento);
  end loop;
--                      ======================================================
--                         Final Bloco de Prorrogação Automática - Importados
--                      =====================================================

--                      ======================================================
--                         Início Bloco de Prorrogação IN-2019 - Importados
--                      =====================================================
  -- Criando o processo Adicional de prorrogação entradas Importadas
  if v_s_adicional_ativo_nfimp = 'S' then
    -- Cria processo apenas se tiver registro para prorrogar
    w_n_valida_exec := 0;
    -- Select que busca os itens que iram vencer no mês atual que são do tipo RECOF agrupando por DI
    for cLoop in (select oadm.id_item_entrada_di,
                         SUM(FNC_GET_SALDO_ENTRADA_BAIXA(IE.ID_ITEM_ENTRADA)) SALDO,
                         ie.data_vencimento DT_VENCIMENTO,
                         ie.tipo_entrada,
                         di.dt_desembaraco_date
                    from declaracao_importacao di,
                         op_adicao_detalhe_mercadoria oadm,
                         itens_entrada ie
                    where FNC_GET_TIPO_ENTRADA(IE.TIPO_ENTRADA, 'RECOF_IMPORTADO') = 'S'
                      and FNC_GET_TIPO_ENTRADA(IE.TIPO_ENTRADA, 'PRE_SERIE') = 'N'
                      and FNC_GET_TIPO_ENTRADA(IE.TIPO_ENTRADA, 'DESMONTE') = 'N'
                      and FNC_GET_TIPO_ENTRADA(ie.TIPO_ENTRADA, 'RPI') = 'N'                      
                      and di.nr_declaracao_imp = oadm.nr_declaracao_imp
                      and not exists (select 1 from op_adicao_detalhe_mercadoria oadm1
                                   where di.nr_declaracao_imp = oadm1.nr_declaracao_imp
                                     and oadm1.flag_liberada = 'N')
                      and ie.id_item_entrada_di = oadm.id_item_entrada_di
                      and di.dt_desembaraco_date between v_d_ini_periodo_nfimp and v_d_fim_periodo_nfimp_rf -- periodo de emissao de NFs considerado na IN 1960
                      and exists (select 1 from ITENS_PROCESSO_PRORROGACAO ipp where ipp.id_item_entrada_di = oadm.id_item_entrada_di) -- deve ter dados na ITENS_PROCESSO_PRORROGACAO, prorrogacao prévia
                      and ie.data_vencimento < add_months(di.dt_desembaraco_date, v_n_meses_pos_data_nfimp) -- quando já houver uma prorrogacao com data de 3 anos após desembaraco, não permite mais prorrogar
                group by oadm.id_item_entrada_di,
                         ie.data_vencimento,
                         ie.tipo_entrada,
                         di.dt_desembaraco_date
                   having SUM(FNC_GET_SALDO_ENTRADA_BAIXA(IE.ID_ITEM_ENTRADA)) > 0
                  ) loop

      if w_n_valida_exec = 0 then
        -- Criando o processo de prorrogação
        insert into PROCESSO_PRORROGACAO
          (ID_PROCESSO, DT_SOLICITACAO)
        values
          (SEQ_PROCESSO_PRORROGACAO.nextval, PKG_TR_SYSDATE.FNC_TR_SYSDATE)
        returning ID_PROCESSO into w_n_IdProcesso;
        w_n_valida_exec := 1;

        -- Gravando o LOG da operação realizada
        insert into LOG_PRORROGACAO_DA
          (USUARIO, DT_ALTERACAO, ID_PROCESSO, OBSERVACAO_LOG)
        values
          ('INTERFACE',
           PKG_TR_SYSDATE.FNC_TR_SYSDATE,
           w_n_IdProcesso,
           v_s_obs_nfimp);
      end if;

      -- Alterando a DATA de VENCIMENTO da DA e indicando qual é o ID do processo de prorrogação
      update PRORROGACAO_DA pd
         SET ID_PROCESSO           = w_n_IdProcesso,
             pd.dt_vencimento      = ADD_MONTHS(cLoop.dt_desembaraco_date, v_n_meses_pos_data_nfimp), -- sempre atualiza para o prazo final permitido
             pd.observacao         = v_s_obs_nfimp,
             PRORROGADO            = PRORROGADO + 1, -- pode-se somar mais um porque v_n_meses_pos_data_nfimp = 36 e obriga-se que a primeira prorrogação seja pela "prorrogação normal"
             S_PRORROGA_AUTOMATICO = 'S'
       where ID_ITEM_ENTRADA_DI = cLoop.id_item_entrada_di
         and ID_ITEM_ENTRADA is null;
      ----
      insert into ITENS_PROCESSO_PRORROGACAO
        (ID_PROCESSO, ID_ITEM_ENTRADA_DI, SALDO, DT_VENCIMENTO_ANT)
      values
        (w_n_IdProcesso,
         cLoop.id_item_entrada_di,
         cLoop.SALDO,
         cLoop.dt_vencimento);
    end loop;
  end if;
--                      ======================================================
--                         Final Bloco de Prorrogação IN-2019 - Importados
--                      =====================================================

--                      ==================================================================
--                         Início Bloco de Prorrogação Automática - Importados - desmonte
--                      ==================================================================
  w_n_valida_exec := 0;
  if pkg_param.get_parametro_alfa(274) = 'S' THEN
    for cLoop in (select o.id_item_nfe_desm_result,
                         SUM(FNC_GET_SALDO_ENTRADA_BAIXA(I.ID_ITEM_ENTRADA)) SALDO,
                         p.dt_vencimento,
                         i.tipo_entrada,
                         i.id_item_nf_entrada
                    from prorrogacao_desmonte         p,
                         ORD_DESM_ITEM_NFE_RESULTANTE o,
                         itens_entrada                i,
                         entradas e
                   where o.id_item_nfe_desm_result = p.id_item_nfe_desm_result
                     and o.id_item_nf_entrada_resultante = i.id_item_nf_entrada
                     and e.id_entrada = i.id_entrada
                     and not exists (select 1
                                    from op_adicao_detalhe_mercadoria oadm1
                                    where e.doc_origem = oadm1.nr_declaracao_imp
                                          and oadm1.flag_liberada = 'N')
                     and p.prorrogado = 0
                     and FNC_GET_TIPO_ENTRADA(i.TIPO_ENTRADA, 'RECOF') = 'S'
                     and FNC_GET_TIPO_ENTRADA(i.TIPO_ENTRADA, 'DESMONTE') = 'S'
                     and FNC_GET_TIPO_ENTRADA(i.TIPO_ENTRADA, 'PRE_SERIE') = 'N'
                     --and FNC_GET_TIPO_ENTRADA(i.TIPO_ENTRADA, 'RPI') = 'N'
                     and p.id_item_entrada is null
                     and i.data_vencimento between d_ctrl_interface and ADD_MONTHS(trunc(PKG_TR_SYSDATE.FNC_TR_SYSDATE),1) -- range: dt da ultima exec interface mais 1 mes de margem da data atual
                   group by
                     o.id_item_nfe_desm_result,
                     p.dt_vencimento,
                     i.tipo_entrada,
                     i.id_item_nf_entrada
                   having SUM(FNC_GET_SALDO_ENTRADA_BAIXA(I.ID_ITEM_ENTRADA)) > 0
                   ) loop

      if w_n_valida_exec = 0 then
        -- Criando o processo de prorrogação de DESMONTE
        insert into PROCESSO_PRORROGACAO_DESMONTE
          (ID_PROCESSO, DT_SOLICITACAO)
        values
          (SEQ_PROC_PRORROG_DESM.nextval, PKG_TR_SYSDATE.FNC_TR_SYSDATE)
        returning ID_PROCESSO into w_n_IdProcesso_desmonte;

        w_n_valida_exec := 1;

        -- Gravando o LOG da operação realizada
        insert into LOG_PRORROGACAO_DESMONTE
          (id_log_prorrogacao_desmonte,
           USUARIO,
           DT_ALTERACAO,
           ID_PROCESSO,
           OBSERVACAO_LOG)
        values
          (seq_log_prorrog_desmonte.nextval,
           'INTERFACE',
           PKG_TR_SYSDATE.FNC_TR_SYSDATE,
           w_n_IdProcesso_desmonte,
           'Inclusão do Processo de Solicitação de Prorrogação');
      end if;

      -- Alterando a DATA DE VENCIMENTO do item e indicando qual o ID do processo de prorrogacao de desmonte
      update prorrogacao_desmonte pd
         set pd.id_processo   = w_n_IdProcesso_desmonte,
             pd.dt_vencimento = add_months(pd.dt_vencimento,pkg_param.get_parametro_num(72)),
             pd.observacao    = 'Data do Vencimento do item resultante do desmonte gerado automaticamente.',
             pd.prorrogado    = pd.prorrogado + 1,
             pd.s_prorroga_automatico = 'S'
       where pd.id_item_nfe_desm_result = cLoop.id_item_nfe_desm_result
         and pd.ID_ITEM_ENTRADA is null;

      insert into ITENS_PROC_PRORROG_DESM
        (id_itens_processo_prorrogacao,
         ID_PROCESSO,
         DT_VENCIMENTO_ANT,
         SALDO,
         id_item_nfe_desm_result)
      values
        (seq_itens_proc_prorrog_desm.nextval,
         w_n_IdProcesso_desmonte,
         cLoop.dt_vencimento,
         cLoop.saldo,
         cLoop.id_item_nfe_desm_result);
    end loop;
    
--                      ==================================================================
--                         Final Bloco de Prorrogação Automática - Importados - desmonte
--                      ==================================================================

--                      ==================================================================
--                         Início Bloco de Prorrogação IN-2019 - Importados - desmonte
--                      ==================================================================
 
    if v_s_adicional_ativo_desm = 'S' then
      w_n_valida_exec := 0;
      for cLoop in (select odinr.id_item_nfe_desm_result,
                           SUM(FNC_GET_SALDO_ENTRADA_BAIXA(I.ID_ITEM_ENTRADA)) SALDO,
                           i.data_vencimento dt_vencimento,
                           i.tipo_entrada,
                           i.id_item_nf_entrada,
                           di.dt_desembaraco_date
                      from ord_desm_item_nfe_resultante odinr,
                           ordem_desmonte_item odi,
                           ordem_desmonte od,
                           ord_desm_item_itens_entrada odiie,
                           op_adicao_detalhe_mercadoria oadm,
                           itens_entrada i,
                           declaracao_importacao di
                     where odinr.id_item_nf_entrada_resultante = i.id_item_nf_entrada
                       and odinr.id_item_desmonte = odi.id_item_desmonte
                       and od.id_desmonte = odi.id_desmonte
                       and odiie.id_desmonte = od.id_desmonte
                       and odiie.id_item_entrada_di_desmontado = oadm.id_item_entrada_di
                       and di.nr_declaracao_imp = oadm.nr_declaracao_imp
                       and not exists (select 1 from op_adicao_detalhe_mercadoria oadm1
                                      where di.nr_declaracao_imp = oadm1.nr_declaracao_imp
                                        and oadm1.flag_liberada = 'N')
                       and i.prorrogado > 0
                       and FNC_GET_TIPO_ENTRADA(i.TIPO_ENTRADA, 'RECOF_NACIONAL') = 'S'
                       and FNC_GET_TIPO_ENTRADA(i.TIPO_ENTRADA, 'DESMONTE') = 'S'
                       and FNC_GET_TIPO_ENTRADA(i.TIPO_ENTRADA, 'PRE_SERIE') = 'N'
                       and FNC_GET_TIPO_ENTRADA(i.TIPO_ENTRADA, 'RPI') = 'N'
                       and exists (select 1 from ITENS_PROC_PRORROG_DESM ippd where ippd.id_item_nfe_desm_result = odinr.id_item_nfe_desm_result) --prorogacao anterior via interface
                       and di.dt_desembaraco_date between v_d_ini_periodo_desm and v_d_fim_periodo_desm_rf --periodo da prorrogacao adicional
                       and i.data_vencimento < add_months(di.dt_desembaraco_date, v_n_meses_pos_data_desm) -- quando atingir a prorrogacao final não deve mais prorrogar
                     group by
                       odinr.id_item_nfe_desm_result,
                       i.data_vencimento,
                       i.tipo_entrada,
                       i.id_item_nf_entrada,
                       di.dt_desembaraco_date
                     having SUM(FNC_GET_SALDO_ENTRADA_BAIXA(I.ID_ITEM_ENTRADA)) > 0
                   ) loop

        if w_n_valida_exec = 0 then
          -- Criando o processo de prorrogação de DESMONTE
          insert into PROCESSO_PRORROGACAO_DESMONTE
            (ID_PROCESSO, DT_SOLICITACAO)
          values
            (SEQ_PROC_PRORROG_DESM.nextval, PKG_TR_SYSDATE.FNC_TR_SYSDATE)
          returning ID_PROCESSO into w_n_IdProcesso_desmonte;

          w_n_valida_exec := 1;

          -- Gravando o LOG da operação realizada
          insert into LOG_PRORROGACAO_DESMONTE
            (id_log_prorrogacao_desmonte,
             USUARIO,
             DT_ALTERACAO,
             ID_PROCESSO,
             OBSERVACAO_LOG)
          values
            (seq_log_prorrog_desmonte.nextval,
             'INTERFACE',
             PKG_TR_SYSDATE.FNC_TR_SYSDATE,
             w_n_IdProcesso_desmonte,
             v_s_obs_desm);
        end if;

        -- Alterando a DATA DE VENCIMENTO do item e indicando qual o ID do processo de prorrogacao de desmonte
        update prorrogacao_desmonte pd
           set pd.id_processo   = w_n_IdProcesso_desmonte,
               pd.dt_vencimento = ADD_MONTHS(cLoop.dt_desembaraco_date, v_n_meses_pos_data_desm), -- sempre atualiza para o prazo final permitido
               pd.observacao    = v_s_obs_desm,
               pd.prorrogado    = pd.prorrogado + 1 --pode-se apenas somar 1 pois a garantia de que só se está prorrogando 1 período é que v_n_meses_pos_data_desm=36 e que a primeira prorrogação é feito pelo processo normal
         where pd.id_item_nfe_desm_result = cLoop.id_item_nfe_desm_result
           and pd.ID_ITEM_ENTRADA is null;

        insert into ITENS_PROC_PRORROG_DESM
          (id_itens_processo_prorrogacao,
           ID_PROCESSO,
           DT_VENCIMENTO_ANT,
           SALDO,
           id_item_nfe_desm_result)
        values
          (seq_itens_proc_prorrog_desm.nextval,
           w_n_IdProcesso_desmonte,
           cLoop.dt_vencimento,
           cLoop.saldo,
           cLoop.id_item_nfe_desm_result);
      end loop;
    --
    --
    --
    
    for cLoop in (select odinr.id_item_nfe_desm_result,
                           SUM(FNC_GET_SALDO_ENTRADA_BAIXA(I.ID_ITEM_ENTRADA)) SALDO,
                           i.data_vencimento dt_vencimento,
                           i.tipo_entrada,
                           i.id_item_nf_entrada,
                           nfe.data_emissao
                      from ord_desm_item_nfe_resultante odinr,
                           ordem_desmonte_item odi,
                           ordem_desmonte od,
                           ord_desm_item_itens_entrada odiie,
                           op_adicao_detalhe_mercadoria oadm,
                           itens_entrada i,
                           declaracao_importacao di,
                           nf_entrada nfe,
                           itens_nf_entrada infe
                     where odinr.id_item_nf_entrada_resultante = i.id_item_nf_entrada
                       and odinr.id_item_desmonte = odi.id_item_desmonte
             
             AND odiie.ID_ITEM_NF_ENTRADA_DESMONTADO = infe.ID_ITEM_NF_ENTRADA
             AND infe.ID_NF_ENTRADA = nfe.ID_NF_ENTRADA
                       
             and od.id_desmonte = odi.id_desmonte
                       and odiie.id_desmonte = od.id_desmonte
                       and odiie.id_item_entrada_di_desmontado = oadm.id_item_entrada_di
                       and di.nr_declaracao_imp = oadm.nr_declaracao_imp
                       and not exists (select 1 from op_adicao_detalhe_mercadoria oadm1
                                      where di.nr_declaracao_imp = oadm1.nr_declaracao_imp
                                        and oadm1.flag_liberada = 'N')
                       and i.prorrogado > 0
                       and FNC_GET_TIPO_ENTRADA(i.TIPO_ENTRADA, 'RECOF_NACIONAL') = 'S'
                       and FNC_GET_TIPO_ENTRADA(i.TIPO_ENTRADA, 'DESMONTE') = 'S'
                       and FNC_GET_TIPO_ENTRADA(i.TIPO_ENTRADA, 'PRE_SERIE') = 'N'
                       and FNC_GET_TIPO_ENTRADA(i.TIPO_ENTRADA, 'RPI') = 'N'
             
                       and exists (select 1 from ITENS_PROC_PRORROG_DESM ippd where ippd.id_item_nfe_desm_result = odinr.id_item_nfe_desm_result) --prorogacao anterior via interface
                       and di.dt_desembaraco_date between v_d_ini_periodo_desm and v_d_fim_periodo_desm_rf --periodo da prorrogacao adicional
                       and nfe.data_emissao < add_months(di.dt_desembaraco_date, v_n_meses_pos_data_desm) -- quando atingir a prorrogacao final não deve mais prorrogar
                     group by
                       odinr.id_item_nfe_desm_result,
                       i.data_vencimento,
                       i.tipo_entrada,
                       i.id_item_nf_entrada,
                       di.dt_desembaraco_date
                     having SUM(FNC_GET_SALDO_ENTRADA_BAIXA(I.ID_ITEM_ENTRADA)) > 0
                   ) loop

        if w_n_valida_exec = 0 then
          -- Criando o processo de prorrogação de DESMONTE
          insert into PROCESSO_PRORROGACAO_DESMONTE
            (ID_PROCESSO, DT_SOLICITACAO)
          values
            (SEQ_PROC_PRORROG_DESM.nextval, PKG_TR_SYSDATE.FNC_TR_SYSDATE)
          returning ID_PROCESSO into w_n_IdProcesso_desmonte;

          w_n_valida_exec := 1;

          -- Gravando o LOG da operação realizada
          insert into LOG_PRORROGACAO_DESMONTE
            (id_log_prorrogacao_desmonte,
             USUARIO,
             DT_ALTERACAO,
             ID_PROCESSO,
             OBSERVACAO_LOG)
          values
            (seq_log_prorrog_desmonte.nextval,
             'INTERFACE',
             PKG_TR_SYSDATE.FNC_TR_SYSDATE,
             w_n_IdProcesso_desmonte,
             v_s_obs_desm);
        end if;

        -- Alterando a DATA DE VENCIMENTO do item e indicando qual o ID do processo de prorrogacao de desmonte
        update prorrogacao_desmonte pd
           set pd.id_processo   = w_n_IdProcesso_desmonte,
               pd.dt_vencimento = ADD_MONTHS(cLoop.data_emissao, v_n_meses_pos_data_desm), -- sempre atualiza para o prazo final permitido
               pd.observacao    = v_s_obs_desm,
               pd.prorrogado    = pd.prorrogado + 1 --pode-se apenas somar 1 pois a garantia de que só se está prorrogando 1 período é que v_n_meses_pos_data_desm=36 e que a primeira prorrogação é feito pelo processo normal
         where pd.id_item_nfe_desm_result = cLoop.id_item_nfe_desm_result
           and pd.ID_ITEM_ENTRADA is null;

        insert into ITENS_PROC_PRORROG_DESM
          (id_itens_processo_prorrogacao,
           ID_PROCESSO,
           DT_VENCIMENTO_ANT,
           SALDO,
           id_item_nfe_desm_result)
        values
          (seq_itens_proc_prorrog_desm.nextval,
           w_n_IdProcesso_desmonte,
           cLoop.dt_vencimento,
           cLoop.saldo,
           cLoop.id_item_nfe_desm_result);
      end loop;
    
    --
    --
    --
    end if;
  END IF;
--                      ==================================================================
--                         Final Bloco de Prorrogação IN-2019 - Importados - desmonte
--                      ==================================================================

--                      ==================================================================
--                         Início Bloco de Prorrogação Automática - Recof Nacional
--                      ==================================================================
  w_n_valida_exec := 0;
  -- Criando o processo de prorrogação entradas Nacionais
  for cLoop in (select ipp.n_id_item_nf_entrada,
             ine.id_nf_entrada,
             SUM(FNC_GET_SALDO_ENTRADA_BAIXA(I.ID_ITEM_ENTRADA)) SALDO,
             ipp.D_DT_VENCIMENTO_ANT,
             i.tipo_entrada,
             i.id_item_entrada,
             pd.n_id_doc_prazo
          from PRAZO_PERMANENCIA_ITENS ipp,
               PRAZO_PERMANENCIA_DOC   pd,
               itens_entrada           i,
               itens_nf_entrada        ine
         where i.id_item_nf_entrada = ipp.n_id_item_nf_entrada
           and pd.N_ID_PRAZO = ipp.N_ID_PRAZO
           and pd.N_ID_NF_ENTRADA = ine.id_nf_entrada
           and ine.id_item_nf_entrada = ipp.n_id_item_nf_entrada
           and pd.n_prorrogado = 0
           and not exists (select 1
              from itens_nf_entrada inf
             where inf.id_nf_entrada = pd.N_ID_NF_ENTRADA
               and nvl(inf.flag_liberada_itnf,'S') = 'N')
           and FNC_GET_TIPO_ENTRADA(i.TIPO_ENTRADA, 'RECOF_NACIONAL') = 'S'
           --and FNC_GET_TIPO_ENTRADA(i.TIPO_ENTRADA, 'RPI') = 'N'
           and ipp.n_id_item_entrada is null
           and i.data_vencimento between d_ctrl_interface and ADD_MONTHS(trunc(PKG_TR_SYSDATE.FNC_TR_SYSDATE),1) -- range: dt da ultima exec interface mais 1 mes de margem da data atual
         group by
           ipp.n_id_item_nf_entrada,
           ine.id_nf_entrada,
           ipp.D_DT_VENCIMENTO_ANT,
           i.tipo_entrada,
           i.id_item_entrada,
           pd.n_id_doc_prazo
         having SUM(FNC_GET_SALDO_ENTRADA_BAIXA(I.ID_ITEM_ENTRADA)) > 0
         ) loop

    if w_n_valida_exec = 0 then
      insert into PRAZO_PERMANENCIA
        (D_DT_SOLICITACAO, S_OBSERVACAO, S_PRORROGA_AUTOMATICO)
      values
        (PKG_TR_SYSDATE.FNC_TR_SYSDATE,
         'Prorrogação Entradas Nacionais gerado automaticamente via INTERFACE',
         'S')
      returning N_ID_PRAZO into w_n_IdPrazo;

      w_n_valida_exec := 1;

      -- Gravando o LOG da operação realizada
      insert into PRAZO_PERMANENCIA_LOG
        (S_USUARIO, D_DT_ALTERACAO, N_ID_PRAZO, S_OBSERVACAO_LOG)
      values
        ('INTERFACE',
         PKG_TR_SYSDATE.FNC_TR_SYSDATE,
         w_n_IdPrazo,
         'Inclusão de Prorrogação Automática via Interface');
    end if;

  -- Update na PRAZO_PERMANENCIA_DOC
  update PRAZO_PERMANENCIA_DOC
     set n_prorrogado = 1
   where n_id_doc_prazo = cLoop.n_id_doc_prazo;

    -- Associa Prazo_Permanencia com NF_Entrada
    begin
      insert into PRAZO_PERMANENCIA_DOC
        (N_ID_PRAZO, N_ID_NF_ENTRADA, N_PRORROGADO)
      values
        (w_n_IdPrazo, cLoop.id_nf_entrada, 1);
    exception
      when dup_val_on_index then
        null;
    end;

    --
    begin
      INSERT INTO PRAZO_PERMANENCIA_ITENS
        (N_ID_PRAZO,
         N_ID_ITEM_ENTRADA,
         N_ID_ITEM_NF_ENTRADA,
         D_DT_VENCIMENTO_ANT,
         D_DT_VENCIMENTO_NEW)
      
      VALUES
        (w_n_IdPrazo,
         cLoop.id_item_entrada,
         cLoop.n_id_item_nf_entrada,
         cLoop.d_Dt_Vencimento_Ant,
         ADD_MONTHS(cLoop.d_Dt_Vencimento_Ant,
                    pkg_param.get_parametro_num(72)));
    exception
      when dup_val_on_index then
        null;
    end;
               
  end loop;
--                      ==================================================================
--                         Final Bloco de Prorrogação Automática - Recof Nacional
--                      ==================================================================

--                      ==================================================================
--                         Início Bloco de Prorrogação IN-2019 - Recof Nacional
--                      ==================================================================

  -- Criando o processo Adicional de prorrogação entradas Nacionais
  if v_s_adicional_ativo_nfnac = 'S' then

    w_n_valida_exec        := 0;
    v_n_id_nf_entrada_ctrl := 0;

    for cLoop in (select ine.id_item_nf_entrada,
                         ine.id_nf_entrada,
                         SUM(FNC_GET_SALDO_ENTRADA_BAIXA(I.ID_ITEM_ENTRADA)) SALDO,
                         i.tipo_entrada,
                         i.id_item_entrada,
                         nfe.data_emissao,
                         i.data_vencimento
                    from itens_entrada i, itens_nf_entrada ine, nf_entrada nfe
                   where i.id_item_nf_entrada = ine.id_item_nf_entrada
                     and nfe.id_nf_entrada = ine.id_nf_entrada
                     and nfe.flag_liberada = 'S'
                     and i.prorrogado > 0 --só realiza a segunda prorrogação
                     and FNC_GET_TIPO_ENTRADA(i.TIPO_ENTRADA, 'RECOF_NACIONAL') = 'S'
                     and FNC_GET_TIPO_ENTRADA(i.TIPO_ENTRADA, 'RPI') = 'N'
                     and nfe.data_emissao between
                         v_d_ini_periodo_nfnac and
                         v_d_fim_periodo_nfnac_rf -- periodo de emissao de NFs considerado na IN 1960
                     and exists (select 1
                            from prazo_permanencia_itens ppi
                           where ppi.n_id_item_nf_entrada =
                                 ine.id_item_nf_entrada) --deve ter dados na prazo_permanencia_itens
                       and  i.data_vencimento < add_months(nfe.data_emissao, v_n_meses_pos_data_nfnac)-- quando já houver uma prorrogacao com data de 3 anos após a emissão da NF, não permite mais prorrogar
                   group by ine.id_item_nf_entrada,
                            ine.id_nf_entrada,
                            i.tipo_entrada,
                            i.id_item_entrada,
                            nfe.data_emissao,
                            i.data_vencimento
                 having SUM(FNC_GET_SALDO_ENTRADA_BAIXA(I.ID_ITEM_ENTRADA)) > 0
                 order by ine.id_nf_entrada, ine.id_item_nf_entrada) -- nao remover order by
    loop

      if w_n_valida_exec = 0 then

        insert into PRAZO_PERMANENCIA
          (D_DT_SOLICITACAO, S_OBSERVACAO, S_PRORROGA_AUTOMATICO)
        values
          (PKG_TR_SYSDATE.FNC_TR_SYSDATE,
           v_s_obs_nfnac,
           'S')
        returning N_ID_PRAZO into w_n_IdPrazo;

        w_n_valida_exec := 1;

        -- Gravando o LOG da operação realizada
        insert into PRAZO_PERMANENCIA_LOG
          (S_USUARIO, D_DT_ALTERACAO, N_ID_PRAZO, S_OBSERVACAO_LOG)
        values
          ('INTERFACE',
           PKG_TR_SYSDATE.FNC_TR_SYSDATE,
           w_n_IdPrazo,
           v_s_obs_nfnac);

      end if;
      --zera variaveis
      v_n_prorrogado := 0;

      -- busca dados da ultima prorrogacao para este item_nf_entrada
      select max(ppd.n_prorrogado),
             max(ppi.d_dt_vencimento_new),
             max(ppd.n_id_doc_prazo)
        into v_n_prorrogado, w_d_dt_prorrogado, v_n_id_doc_prazo
        from PRAZO_PERMANENCIA_DOC ppd, prazo_permanencia_itens ppi
       where ppi.n_id_item_nf_entrada = cLoop.Id_Item_Nf_Entrada
         and ppd.n_id_nf_entrada = cLoop.Id_Nf_Entrada
         and ppi.n_id_prazo = ppd.n_id_prazo
         and ppd.n_id_prazo <> w_n_IdPrazo;

      --controle do update na PRAZO_PERMANENCIA_DOC
      if cLoop.id_nf_entrada <> v_n_id_nf_entrada_ctrl then

        -- Update na PRAZO_PERMANENCIA_DOC
        update PRAZO_PERMANENCIA_DOC ppd
           set n_prorrogado = v_n_prorrogado + 1 -- incrementa prorrogacao de todas NF DOC
         where ppd.n_id_nf_entrada = cLoop.id_nf_entrada;

        v_n_id_nf_entrada_ctrl := cLoop.id_nf_entrada;

      end if;

      -- Associa Prazo_Permanencia com NF_Entrada
      begin
        insert into PRAZO_PERMANENCIA_DOC
          (N_ID_PRAZO, N_ID_NF_ENTRADA, N_PRORROGADO)
        values
          (w_n_IdPrazo, cLoop.id_nf_entrada, v_n_prorrogado + 1 );
      exception
        when dup_val_on_index then
          null;
      end;

      --
       begin
        INSERT INTO PRAZO_PERMANENCIA_ITENS
          (N_ID_PRAZO,
           N_ID_ITEM_ENTRADA,
           N_ID_ITEM_NF_ENTRADA,
           D_DT_VENCIMENTO_ANT,
           D_DT_VENCIMENTO_NEW)
        VALUES
          (w_n_IdPrazo,
           cLoop.id_item_entrada,
           cLoop.id_item_nf_entrada,
           nvl(w_d_dt_prorrogado, ADD_MONTHS(cLoop.Data_Emissao, 12)), -- caso vencimento_new esteja vazia para a ultima prorrog., então não rodou a interface de prorrog. então, busca a data de emissao da NF mais 1 ano.
           ADD_MONTHS(cLoop.data_emissao, v_n_meses_pos_data_nfnac)); -- sempre vencimento final. 3 anos a partir da data da NF devido a IN 1960
        exception
        when dup_val_on_index then
          null;
    end;
    end loop;
  end if;
--                      ==================================================================
--                         Final Bloco de Prorrogação IN-2019 - Recof Nacional
--                      ==================================================================
  -- No final de todo o processamento, atualiza a tabela de controle da interface para a data atual
  update RF_INTERFACE_PRORROGACAO_CTRL set D_CTRL_IN1904 = TRUNC(PKG_TR_SYSDATE.FNC_TR_SYSDATE);

  COMMIT;

end prc_prorrogacao_automatica;
/
