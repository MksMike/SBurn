# -*- coding: utf-8 -*-
# =====================================================================
# S-Py-Analise_ConsistGate.py
# RODAR EM: qualquer maquina com Python 3 + pandas (scipy opcional)
# USO:      python S-Py-Analise_ConsistGate.py <caminho_do_csv>
# ENTRADA:  CSV do S-EA-Test_ConsistencyGate (separador ';')
# ---------------------------------------------------------------------
# O QUE RESPONDE (protocolo do projeto SBurn):
#  1. Custo real por sinal (spread medido linha a linha)
#  2. Quanto a janela de 75 ticks CONSOME (entrada A vs entrada B)
#  3. A consistencia separa bons de maus sinais AQUI? (Spearman)
#  4. Tabela de quintis (calibracao do corte, nunca intuicao)
#  5. Simulacao de cortes: n, taxa de aprovacao, MFE mediano vs custo
#  6. Quebra por sessao aproximada (hora do servidor)
# Regra do projeto: MFE e' excursao maxima, NAO lucro capturavel.
# =====================================================================
import sys
import pandas as pd

try:
    from scipy.stats import spearmanr
    TEM_SCIPY = True
except Exception:
    TEM_SCIPY = False

def carregar(caminho):
    df = pd.read_csv(caminho, sep=';')
    df['time_sig'] = pd.to_datetime(df['time_sig'], format='%Y.%m.%d %H:%M:%S')
    return df

def spearman(a, b):
    # com scipy: rho e p; sem scipy: rho via pandas, p indisponivel
    if TEM_SCIPY:
        rho, p = spearmanr(a, b)
        return rho, p
    return a.corr(b, method='spearman'), float('nan')

def mediana(s):
    return float(s.median())

def linha(t=''):
    print(t)

def bloco(titulo):
    print('\n' + '=' * 64)
    print(titulo)
    print('=' * 64)

def main():
    caminho = sys.argv[1] if len(sys.argv) > 1 else 'test_consistgate.csv'
    df = carregar(caminho)

    bloco('1. CONTEXTO E CUSTO REAL')
    linha(f'Arquivo: {caminho}')
    linha(f'Linhas: {len(df)} | Periodo: {df.time_sig.min()} -> {df.time_sig.max()}')
    linha(f'Status: {df.status.value_counts().to_dict()}')
    linha(f'Direcao: {df.dir.value_counts().to_dict()}')
    sp = df['spread_sig_pts']
    linha(f'Spread no sinal (pts): mediana={mediana(sp):.0f}  p10={sp.quantile(.1):.0f}  p90={sp.quantile(.9):.0f}')
    custo = mediana(sp)                      # round-trip = spread (Standard, sem comissao)
    regua = (2 * custo, 3 * custo)
    linha(f'Custo round-trip (mediana do spread): {custo:.0f} pts')
    linha(f'Regua de viabilidade (2-3x custo): {regua[0]:.0f} a {regua[1]:.0f} pts')
    cm = df['coleta_ms'] / 1000.0
    linha(f'Coleta da janela (s de MERCADO): mediana={mediana(cm):.1f}  p10={cm.quantile(.1):.1f}  p90={cm.quantile(.9):.1f}')

    # analise principal so' com PASS completos
    d = df[df.status == 'PASS'].copy()
    linha(f'Base da analise (PASS): n={len(d)}')

    bloco('2. ENTRADA A (sem gate) vs ENTRADA B (pos-janela)')
    # deslocamento na direcao do sinal durante a janela: >0 = B entra pior
    d['janela_pts'] = (d.price_B - d.price_A) / 0.001 * d.dir
    # nota: 0.001 = ponto do ouro 3 digitos; ajustar se o simbolo mudar
    linha(f'Movimento na janela, na direcao do sinal (pts): mediana={mediana(d.janela_pts):.0f}  '
          f'p25={d.janela_pts.quantile(.25):.0f}  p75={d.janela_pts.quantile(.75):.0f}')
    for h in ('5', '15', '30'):
        ma, mb = mediana(d[f'mfe{h}_A']), mediana(d[f'mfe{h}_B'])
        aa, ab = mediana(d[f'mae{h}_A']), mediana(d[f'mae{h}_B'])
        linha(f'MFE{h:>2}min mediano: A={ma:6.0f}  B={mb:6.0f}  (consumo={ma-mb:+.0f})   '
              f'MAE{h}min: A={aa:.0f}  B={ab:.0f}')

    bloco('3. SPEARMAN: consistencia x resultado (contexto ATUAL)')
    for alvo in ('mfe5_B', 'mfe15_B', 'mfe30_B', 'mae15_B'):
        rho, p = spearman(d['consist'], d[alvo])
        pv = f' p={p:.4f}' if TEM_SCIPY else ''
        linha(f'consist x {alvo:8s}: rho={rho:+.3f}{pv}')
    # cruzamento com direcao (a logica validada): alinhado vs contra
    for nome, g in (('ALINHADO (dir_sensor==dir)', d[d.alinhado == 1]),
                    ('CONTRA', d[d.alinhado == 0])):
        if len(g) > 30:
            rho, p = spearman(g['consist'], g['mfe15_B'])
            linha(f'{nome}: n={len(g)}  medMFE15B={mediana(g.mfe15_B):.0f}  '
                  f'medMAE15B={mediana(g.mae15_B):.0f}  rho(consist,MFE15B)={rho:+.3f}')

    bloco('4. QUINTIS DE CONSISTENCIA (calibracao)')
    d['quintil'] = pd.qcut(d['consist'], 5, labels=['Q1', 'Q2', 'Q3', 'Q4', 'Q5'])
    linha(f'{"Q":>3} {"n":>5} {"consist(faixa)":>16} {"medMFE15B":>10} {"medMAE15B":>10} {"MFE/custo":>9}')
    for q, g in d.groupby('quintil', observed=True):
        lo, hi = g.consist.min(), g.consist.max()
        m15, a15 = mediana(g.mfe15_B), mediana(g.mae15_B)
        linha(f'{q:>3} {len(g):>5} {lo:>7.3f}-{hi:<7.3f} {m15:>10.0f} {a15:>10.0f} {m15/custo:>8.1f}x')

    bloco('5. SIMULACAO DE CORTES (o CSV decide, nao a intuicao)')
    cortes = [d.consist.quantile(x) for x in (.2, .4, .6, .8)]
    linha(f'{"corte":>7} {"alinhado":>9} {"n":>5} {"aprova%":>8} {"medMFE15B":>10} {"medMAE15B":>10} {"MFE/custo":>9}')
    base = len(d)
    for c in cortes:
        for exigir in (False, True):
            g = d[(d.consist >= c) & ((d.alinhado == 1) if exigir else True)]
            if len(g) < 20:
                continue
            m15, a15 = mediana(g.mfe15_B), mediana(g.mae15_B)
            linha(f'{c:>7.3f} {("SIM" if exigir else "nao"):>9} {len(g):>5} '
                  f'{100*len(g)/base:>7.1f}% {m15:>10.0f} {a15:>10.0f} {m15/custo:>8.1f}x')
    m15, a15 = mediana(d.mfe15_B), mediana(d.mae15_B)
    linha(f'{"(sem)":>7} {"nao":>9} {base:>5} {"100.0%":>8} {m15:>10.0f} {a15:>10.0f} {m15/custo:>8.1f}x')

    bloco('6. POR SESSAO (hora do SERVIDOR - aproximacao)')
    d['hora'] = d.time_sig.dt.hour
    faixas = [('Asia aprox (00-07h)', d[(d.hora >= 0) & (d.hora <= 7)]),
              ('Londres aprox (08-15h)', d[(d.hora >= 8) & (d.hora <= 15)]),
              ('NY aprox (16-23h)', d[(d.hora >= 16) & (d.hora <= 23)])]
    for nome, g in faixas:
        if len(g) < 20:
            linha(f'{nome}: n={len(g)} (amostra insuficiente)')
            continue
        rho, _ = spearman(g['consist'], g['mfe15_B'])
        linha(f'{nome}: n={len(g)}  medMFE15B={mediana(g.mfe15_B):.0f}  '
              f'medMAE15B={mediana(g.mae15_B):.0f}  rho={rho:+.3f}')

    if 'state2' in d.columns:
        bloco('7. FILTRO DE CONTEXTO (hipotese: regime alinhado -> assimetria melhor)')
        linha('Assimetria = medMFE15B - medMAE15B (positivo = edge direcional)')
        ctxs = [('state2', 'Estado TF2'), ('state3', 'Estado TF3'),
                ('conflu', 'Confluencia MTF')]
        if 'sp_trend' in d.columns:
            ctxs.append(('sp_trend', 'ScalpPullback (TF de direcao)'))
        for ctx, nome in ctxs:
            ali = d[d[ctx] * d.dir > 0]
            con = d[d[ctx] * d.dir < 0]
            neu = d[d[ctx] == 0]
            linha(f'--- {nome} ---')
            for rot, g in (('alinhado', ali), ('contra', con), ('neutro', neu)):
                if len(g) < 20:
                    linha(f'  {rot:>9}: n={len(g)} (insuficiente)')
                    continue
                m, a = mediana(g.mfe15_B), mediana(g.mae15_B)
                linha(f'  {rot:>9}: n={len(g):>4}  medMFE15B={m:6.0f}  medMAE15B={a:6.0f}  '
                      f'assimetria={m-a:+6.0f}  MFE/custo={m/custo:4.1f}x')
        ex = d[d.exhaust != 0]
        nx = d[d.exhaust == 0]
        bloco('8. EXAUSTAO NO CRUZAMENTO (cruzou vindo de OB/OS?)')
        for rot, g in (('em zona OB/OS', ex), ('fora de zona', nx)):
            if len(g) < 20:
                linha(f'{rot}: n={len(g)} (insuficiente)')
                continue
            m, a = mediana(g.mfe15_B), mediana(g.mae15_B)
            linha(f'{rot}: n={len(g):>4}  medMFE15B={m:6.0f}  medMAE15B={a:6.0f}  '
                  f'assimetria={m-a:+6.0f}')
        # reversao de exaustao na direcao certa: cruzou p/ cima vindo de OS, etc.
        if 'sp_trend' in d.columns:
            combo = d[(d.sp_trend * d.dir > 0) & (d.exhaust == 0)]
            if len(combo) >= 20:
                m, a = mediana(combo.mfe15_B), mediana(combo.mae15_B)
                linha(f'COMBO desenho A (SP alinhado + fora de zona): n={len(combo)}  '
                      f'medMFE15B={m:.0f}  medMAE15B={a:.0f}  assimetria={m-a:+.0f}')
        rev = d[((d.exhaust == -1) & (d.dir == 1)) | ((d.exhaust == 1) & (d.dir == -1))]
        if len(rev) >= 20:
            m, a = mediana(rev.mfe15_B), mediana(rev.mae15_B)
            linha(f'reversao de extremo (OS->compra / OB->venda): n={len(rev)}  '
                  f'medMFE15B={m:.0f}  medMAE15B={a:.0f}  assimetria={m-a:+.0f}')

    if 'm1_cross' in d.columns:
        bloco('9. GEOMETRIA DO CRUZAMENTO (caca ao whipsaw)')
        d['pos'] = d.m1_cross * d.dir   # <0 = nasceu contra a perna nova
        faixas = [('contra profundo (<-5)', d[d.pos < -5]),
                  ('contra (-5..-1)',       d[(d.pos >= -5) & (d.pos < -1)]),
                  ('perto de zero (-1..1)', d[(d.pos >= -1) & (d.pos <= 1)]),
                  ('a favor (1..5)',        d[(d.pos > 1) & (d.pos <= 5)]),
                  ('a favor profundo (>5)', d[d.pos > 5])]
        for nome, g in faixas:
            if len(g) < 30: linha(f'  {nome}: n={len(g)} insuf.'); continue
            m, a = mediana(g.mfe15_B), mediana(g.mae15_B)
            linha(f'  {nome:<22} n={len(g):>4}  medMFE15B={m:6.0f}  medMAE15B={a:6.0f}  assim={m-a:+6.0f}')
        d['gap'] = d.hist_cross.abs()
        linha('  --- profundidade |main-signal| (tercis) ---')
        try:
            d['gap_t'] = pd.qcut(d.gap, 3, labels=['raso', 'medio', 'fundo'])
            for t, g in d.groupby('gap_t', observed=True):
                m, a = mediana(g.mfe15_B), mediana(g.mae15_B)
                linha(f'  {t:<8} n={len(g):>4}  assim={m-a:+6.0f}  (gap {g.gap.min():.2f}-{g.gap.max():.2f})')
        except Exception:
            pass

    bloco('LEMBRETES DE HONESTIDADE')
    linha('- MFE = excursao maxima, nao lucro capturavel.')
    linha('- Amostra curta (< 1 mes) = provisorio; decisao so com a janela grande + OOS.')
    linha('- Nenhum corte vira parametro sem repetir esta analise no dataset grande.')

if __name__ == '__main__':
    main()
