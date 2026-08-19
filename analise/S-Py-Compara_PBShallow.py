# -*- coding: utf-8 -*-
# =====================================================================
# S-Py-Compara_PBShallow.py
# RODAR EM: qualquer maquina com Python 3 + pandas
# USO:      python S-Py-Compara_PBShallow.py <csv1> [<csv2> ...]
#           (o rotulo de cada rodada sai do nome do arquivo: pbs_<TAG>.csv)
# ENTRADA:  CSVs do S-EA-Test_ConsistencyGate (separador ';')
# ---------------------------------------------------------------------
# PARA QUE SERVE: comparar as 5 rodadas do pre-registro de SIG_PBSHALLOW
# lado a lado. O S-Py-Analise_ConsistGate.py responde as perguntas DENTRO
# de um arquivo; este responde a unica pergunta que atravessa arquivos --
# a grade mudou frequencia sem custar assimetria?
#
# METRICAS (padrao do projeto, CLAUDE.md secao 4):
#   entrada A     = bid do 1o tick da barra seguinte ao sinal
#   horizontes    = 5/15/30 BARRAS do TF do grafico
#   assimetria    = mediana(MFE) - mediana(MAE), em pontos
#   custo         = mediana do spread medido linha a linha no proprio CSV
#
# AVISOS QUE ANDAM JUNTO DO NUMERO (nao sao rodape):
#   - MFE e' excursao maxima, NAO lucro capturavel.
#   - MFE/MAE dizem o QUE aconteceu, nunca em QUE ORDEM.
#   - assimetria > 0 e' condicao NECESSARIA, nunca suficiente.
# =====================================================================
import os
import sys

import pandas as pd

HORIZONTES = (5, 15, 30)


def rotulo(caminho):
    base = os.path.basename(caminho)
    base = base[:-4] if base.lower().endswith('.csv') else base
    return base[4:] if base.startswith('pbs_') else base


def carrega(caminho):
    df = pd.read_csv(caminho, sep=';')
    df['time_sig'] = pd.to_datetime(df['time_sig'], format='%Y.%m.%d %H:%M:%S')
    return df


def resume(caminho):
    df = carrega(caminho)
    n = len(df)
    if n == 0:
        return {'rodada': rotulo(caminho), 'n': 0}

    dias = df['time_sig'].dt.normalize().nunique()
    custo = float(df['spread_sig_pts'].median())

    r = {
        'rodada': rotulo(caminho),
        'n': n,
        'dias': dias,
        'sig_dia': n / dias if dias else float('nan'),
        'custo': custo,
        'ini': df['time_sig'].min(),
        'fim': df['time_sig'].max(),
        'long': int((df['dir'] > 0).sum()),
        'short': int((df['dir'] < 0).sum()),
    }
    for h in HORIZONTES:
        mfe = float(df['mfe%d_A' % h].median())
        mae = float(df['mae%d_A' % h].median())
        r['mfe%d' % h] = mfe
        r['mae%d' % h] = mae
        r['assim%d' % h] = mfe - mae
    # assimetria em multiplos do ATR da entrada, quando disponivel
    if 'atr_ent' in df.columns:
        atr = df['atr_ent'].replace(0, pd.NA).dropna()
        r['atr'] = float(atr.median()) if len(atr) else float('nan')
    return r


def fmt(v, casas=0):
    if v is None or (isinstance(v, float) and v != v):
        return '-'
    return ('%%.%df' % casas) % v


def main():
    if len(sys.argv) < 2:
        print('uso: python S-Py-Compara_PBShallow.py <csv1> [<csv2> ...]')
        return 1

    linhas = [resume(c) for c in sys.argv[1:]]
    linhas = [l for l in linhas if l.get('n')]
    if not linhas:
        print('nenhum CSV com linhas.')
        return 1

    ctrl = next((l for l in linhas if l['rodada'].upper() == 'CTRL'), None)

    print('=' * 96)
    print('COMPARACAO DAS RODADAS - entrada A, horizontes em BARRAS do TF')
    print('=' * 96)
    print('%-6s %6s %5s %8s %7s %9s %9s %9s %9s' %
          ('rodada', 'n', 'dias', 'sinais/d', 'custo', 'assim5', 'assim15', 'assim30', 'ATR'))
    for l in linhas:
        print('%-6s %6d %5d %8.2f %7s %9s %9s %9s %9s' % (
            l['rodada'], l['n'], l['dias'], l['sig_dia'], fmt(l['custo']),
            fmt(l['assim5']), fmt(l['assim15']), fmt(l['assim30']),
            fmt(l.get('atr'))))

    print()
    print('MFE / MAE medianos (pts), por horizonte')
    print('%-6s %19s %19s %19s' % ('rodada', 'h=5 (mfe/mae)', 'h=15 (mfe/mae)', 'h=30 (mfe/mae)'))
    for l in linhas:
        print('%-6s %19s %19s %19s' % (
            l['rodada'],
            '%s / %s' % (fmt(l['mfe5']), fmt(l['mae5'])),
            '%s / %s' % (fmt(l['mfe15']), fmt(l['mae15'])),
            '%s / %s' % (fmt(l['mfe30']), fmt(l['mae30']))))

    if ctrl:
        print()
        print('=' * 96)
        print('CRITERIO PRE-REGISTRADO (docs\\S-Doc-PreReg_PBSHALLOW.md secao 4)')
        print('=' * 96)
        print('%-6s %10s %12s %12s   %s' %
              ('rodada', 'sig/d vs', 'assim30', 'vs custo', 'veredito'))
        for l in linhas:
            if l is ctrl:
                continue
            razao = l['sig_dia'] / ctrl['sig_dia'] if ctrl['sig_dia'] else float('nan')
            a30, custo = l['assim30'], l['custo']
            if a30 <= custo:
                v = 'REJEITA (nao paga o spread)'
            elif razao <= 1.0:
                v = 'REJEITA (frequencia nao subiu)'
            elif a30 >= ctrl['assim30']:
                v = 'PROMOVE a candidato'
            else:
                v = 'TRADE-OFF registrado (decisao do Mike)'
            print('%-6s %9.2fx %12s %12s   %s' %
                  (l['rodada'], razao, fmt(a30), fmt(a30 - custo), v))
        print()
        print('CTRL: %.2f sinais/dia, assim30=%s, custo=%s' %
              (ctrl['sig_dia'], fmt(ctrl['assim30']), fmt(ctrl['custo'])))

    print()
    print('LEMBRAR: MFE e excursao maxima, nao lucro. Assimetria > 0 e condicao')
    print('necessaria, nao suficiente. A ordem dos eventos nao esta aqui.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
