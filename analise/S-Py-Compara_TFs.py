# -*- coding: utf-8 -*-
# =====================================================================
# S-Py-Compara_TFs.py
# RODAR EM: Python 3 + pandas
# USO: python S-Py-Compara_TFs.py arq_M1.csv arq_M5.csv [...]
# Compara os CSVs do S-EA-Test_ConsistencyGate entre timeframes:
#  - tabela mestre (n, sinais/dia, custo, MFE, MAE, assimetria)
#  - filtro de regime (alinhado vs contra) por TF   [pergunta 2]
#  - reversao de exaustao (OS->compra / OB->venda)  [pergunta 5]
#  - estabilidade: 1a metade vs 2a metade do periodo
# Assimetria = medMFE15B - medMAE15B (positivo = edge direcional).
# =====================================================================
import sys, re
import pandas as pd

def carregar(caminho):
    df = pd.read_csv(caminho, sep=';')
    df['time_sig'] = pd.to_datetime(df['time_sig'], format='%Y.%m.%d %H:%M:%S')
    m = re.search(r'PERIOD_([A-Z]+\d+)(?:_([A-Z]+\d+))?', caminho)
    tf = (m.group(1) + '+' + m.group(2)) if (m and m.group(2)) else (m.group(1) if m else '?')
    return tf, df[df.status == 'PASS'].copy()

def med(s): return float(s.median())

def assim(g):
    return med(g.mfe15_B) - med(g.mae15_B)

def main():
    arquivos = sys.argv[1:]
    ordem = {'M1': 1, 'M5': 5, 'M15': 15, 'M30': 30, 'H1': 60}
    chave = lambda x: ordem.get(x[0].split('+')[0], 99)
    dados = sorted([carregar(a) for a in arquivos], key=chave)

    print('\n===================== TABELA MESTRE =====================')
    print(f'{"TF":>4} {"n":>6} {"sin/dia":>8} {"custo":>6} {"medMFE15B":>10} '
          f'{"medMAE15B":>10} {"assimetria":>10} {"MFE/custo":>9}')
    for tf, d in dados:
        dias = max((d.time_sig.max() - d.time_sig.min()).days * 5 / 7, 1)
        custo = med(d.spread_sig_pts)
        m, a = med(d.mfe15_B), med(d.mae15_B)
        print(f'{tf:>4} {len(d):>6} {len(d)/dias:>8.1f} {custo:>6.0f} {m:>10.0f} '
              f'{a:>10.0f} {m-a:>+10.0f} {m/custo:>8.1f}x')

    print('\n============ FILTRO DE REGIME (assimetria alinhado vs contra) ============')
    print('valor = medMFE15B - medMAE15B do grupo | (n)')
    print(f'{"TF":>4} | {"state2 ali":>12} {"state2 con":>12} | '
          f'{"state3 ali":>12} {"state3 con":>12} | {"conflu ali":>12} {"conflu con":>12}')
    for tf, d in dados:
        celulas = []
        for ctx in ('state2', 'state3', 'conflu'):
            for lado in (1, -1):
                g = d[d[ctx] * d.dir > 0] if lado == 1 else d[d[ctx] * d.dir < 0]
                celulas.append(f'{assim(g):+6.0f}({len(g)})' if len(g) >= 20 else f'  n<20({len(g)})')
        print(f'{tf:>4} | {celulas[0]:>12} {celulas[1]:>12} | '
              f'{celulas[2]:>12} {celulas[3]:>12} | {celulas[4]:>12} {celulas[5]:>12}')

    print('\n============ EXAUSTAO: reversao de extremo (OS->compra / OB->venda) ============')
    print(f'{"TF":>4} {"n_rev":>6} {"assim_rev":>10} | {"n_fora":>7} {"assim_fora":>11}')
    for tf, d in dados:
        rev = d[((d.exhaust == -1) & (d.dir == 1)) | ((d.exhaust == 1) & (d.dir == -1))]
        fora = d[d.exhaust == 0]
        s_rev = f'{assim(rev):+10.0f}' if len(rev) >= 20 else '      n<20'
        s_for = f'{assim(fora):+11.0f}' if len(fora) >= 20 else '       n<20'
        print(f'{tf:>4} {len(rev):>6} {s_rev} | {len(fora):>7} {s_for}')

    print('\n============ ESTABILIDADE: confluencia alinhada, 1a vs 2a metade ============')
    print(f'{"TF":>4} {"assim_1a":>10} {"n":>5} {"assim_2a":>10} {"n":>5}')
    for tf, d in dados:
        corte = d.time_sig.min() + (d.time_sig.max() - d.time_sig.min()) / 2
        if True:
            g1 = d[(d.time_sig < corte) & (d.conflu * d.dir > 0)]
            g2 = d[(d.time_sig >= corte) & (d.conflu * d.dir > 0)]
            s1 = f'{assim(g1):+10.0f}' if len(g1) >= 20 else '      n<20'
            s2 = f'{assim(g2):+10.0f}' if len(g2) >= 20 else '      n<20'
            print(f'{tf:>4} {s1} {len(g1):>5} {s2} {len(g2):>5}')

    print('\nLembretes: MFE = excursao maxima, nao lucro; horizonte = 15 BARRAS de cada TF;')
    print('assimetria positiva e condicao necessaria, nao suficiente (falta saida + custo).')

if __name__ == '__main__':
    main()
