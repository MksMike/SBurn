#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
S-Py-Fuso_Servidor.py
PASTA: <repo>\\analise\\

Descobre o FUSO DO SERVIDOR da corretora a partir do export de ticks (ou de
barras), SEM hardcode de corretora, conta ou simbolo.

--------------------------------------------------------------------------
POR QUE ESTE SCRIPT EXISTE
--------------------------------------------------------------------------
Sensores de sessao (Asia / Londres / NY) e qualquer coisa com fronteira de
calendario dependem de saber que horas sao, de verdade, no relogio do
servidor. Um erro de 1 hora numa sessao de 8h contamina 12% da janela; numa
sobreposicao de 3h, 33%.

Pior: o deslocamento NAO e' constante. O servidor tipicamente segue o horario
de verao EUROPEU, e o americano nao vira no mesmo dia. Existe um intervalo de
~3 semanas em marco (e ~1 em outubro/novembro) em que as sessoes americanas
andam uma hora em relacao ao relogio do servidor.

--------------------------------------------------------------------------
O PRINCIPIO: NAO ASSUMIR, MEDIR
--------------------------------------------------------------------------
Nao perguntamos "qual o fuso da Exness". Usamos ANCORAS DE MUNDO REAL que a
corretora nao controla e deixamos o dado dizer onde elas caem:

  ANCORA PRIMARIA - fronteira semanal.
     O mercado de metais fecha e reabre em instantes do mundo real. Em que
     hora do relogio do SERVIDOR isso aparece e' medicao direta.

  IDENTIFICACAO DO CALENDARIO - a DATA do salto.
     DST europeu vira no ultimo domingo de marco; o americano, no segundo.
     Observando semana a semana em que data a fronteira pula 1h, a data
     identifica QUAL calendario o servidor segue. Isso e' melhor que qualquer
     tabela fixa: pega tambem mudanca permanente de fuso ou migracao de
     servidor no meio da janela.

  VERIFICACAO INDEPENDENTE - perfil de atividade.
     Ticks por hora do dia, semana contra semana. Se o perfil inteiro desliza
     1h na mesma semana em que a fronteira pulou, sao duas evidencias
     independentes apontando junto.

--------------------------------------------------------------------------
O QUE O SCRIPT NAO FAZ
--------------------------------------------------------------------------
- Nao chuta. Com evidencia fraca ele RECUSA responder e diz por que.
- Nao devolve um numero unico. Devolve uma TABELA DE PERIODOS (offset valido
  de tal data a tal data), pelo mesmo motivo da coluna de proveniencia do
  modulo historico: dado que muda de natureza no meio da janela tem que
  carregar isso explicitamente.
- Nao decide nada sobre estrategia. Calibra; nao escolhe (S-Doc-Portabilidade).

--------------------------------------------------------------------------
USO
--------------------------------------------------------------------------
    python S-Py-Fuso_Servidor.py <arquivo_export> [--saida periodos.csv]

Aceita export de TICKS ou de BARRAS do MT5 (delimitador e colunas detectados
automaticamente). Precisa apenas das colunas de data e hora.
"""

import argparse
import os
import sys
from collections import Counter
from datetime import datetime, timedelta, timezone

import numpy as np
import pandas as pd

# --------------------------------------------------------------------------
# LIMIARES - os dois unicos, e ambos justificados por separacao de ordem de
# grandeza, nao por escolha estetica.
# --------------------------------------------------------------------------

# Lacuna que caracteriza fim de semana. O fechamento de metais dura ~48h; a
# pausa diaria dura ~1h. 24h separa os dois com fator 2 de margem dos DOIS
# lados. A distribuicao de lacunas e' impressa no relatorio para o corte ser
# auditavel em vez de aceito na fe.
LACUNA_FIMSEMANA_H = 24.0

# Uma transicao de horario de verao so' e' declarada se PERSISTIR. Semana de
# feriado desloca a fronteira e produziria falso positivo: sem esta guarda, o
# Natal vira "mudanca de fuso".
SEMANAS_CONFIRMACAO = 2


# ==========================================================================
# RELATORIO
# ==========================================================================

_SAIDA = []


def linha(txt=''):
    _SAIDA.append(txt)
    print(txt)


def bloco(titulo):
    linha()
    linha('=' * 74)
    linha('  ' + titulo)
    linha('=' * 74)


# ==========================================================================
# 1. LEITURA TOLERANTE DO EXPORT
# ==========================================================================

def _detectar_sep(primeira_linha):
    """Delimitador = o candidato mais frequente na linha de cabecalho."""
    cand = {'\t': primeira_linha.count('\t'),
            ';': primeira_linha.count(';'),
            ',': primeira_linha.count(',')}
    sep = max(cand, key=cand.get)
    return sep if cand[sep] > 0 else '\t'


def _limpar(nome):
    return nome.strip().strip('<>').strip().lower()


def _achar_colunas(cols):
    """Devolve (col_data, col_hora) ou (col_datetime, None)."""
    limpos = {_limpar(c): c for c in cols}

    col_d = next((limpos[k] for k in ('date', 'data') if k in limpos), None)
    col_h = next((limpos[k] for k in ('time', 'hora') if k in limpos), None)
    if col_d and col_h:
        return col_d, col_h

    for k in ('datetime', 'timestamp', 'date_time', 'time'):
        if k in limpos:
            return limpos[k], None

    # ultimo recurso: as duas primeiras colunas
    if len(cols) >= 2:
        return cols[0], cols[1]
    raise ValueError('Nao consegui identificar colunas de data/hora.')


def carregar_minutos(caminho):
    """
    Devolve uma Series indexada por MINUTO (hora do servidor) com a contagem
    de registros em cada minuto.

    Trabalhar em resolucao de MINUTO, e nao de tick, e' deliberado: reduz
    milhoes de linhas a algumas centenas de milhares de chaves e e' precisao
    de sobra para medir um deslocamento de 1 HORA. O custo de memoria deixa de
    depender do tamanho do arquivo.
    """
    # Cache: agregar 63M ticks a minutos leva minutos de CPU e o resultado e'
    # deterministico. A chave inclui o TAMANHO do arquivo, entao export
    # re-exportado (tamanho diferente) invalida o cache sozinho.
    cache = os.path.join(os.environ.get('TEMP', '.'),
                         'sburn_minutos_%s_%d.csv'
                         % (os.path.basename(caminho)[:40].replace('.', '_'),
                            os.path.getsize(caminho)))
    if os.path.isfile(cache):
        c = pd.read_csv(cache, sep=';')
        sc = pd.Series(c['n'].values,
                       index=pd.to_datetime(c['minuto'])).sort_index()
        return sc, int(c['n'].sum())

    with open(caminho, 'r', encoding='utf-8', errors='ignore') as f:
        cabecalho = f.readline()
    sep = _detectar_sep(cabecalho)

    amostra = pd.read_csv(caminho, sep=sep, nrows=5, dtype=str)
    col_d, col_h = _achar_colunas(list(amostra.columns))

    usecols = [col_d] if col_h is None else [col_d, col_h]
    contagem = Counter()
    linhas = 0

    for pedaco in pd.read_csv(caminho, sep=sep, usecols=usecols,
                              dtype=str, chunksize=1_000_000):
        linhas += len(pedaco)
        if col_h is None:
            # coluna unica: 'YYYY.MM.DD HH:MM:SS...' -> corta no minuto
            chaves = pedaco[col_d].str.slice(0, 16)
        else:
            chaves = pedaco[col_d].str.strip() + ' ' + \
                     pedaco[col_h].str.strip().str.slice(0, 5)
        contagem.update(chaves.dropna().tolist())

    if not contagem:
        raise ValueError('Arquivo sem registros legiveis.')

    # parse so' das chaves UNICAS (ordens de grandeza menos trabalho)
    chaves = pd.Series(list(contagem.keys()))
    momentos = pd.to_datetime(chaves.str.replace('.', '-', regex=False),
                              errors='coerce')
    valores = np.fromiter(contagem.values(), dtype=np.int64,
                          count=len(contagem))

    s = pd.Series(valores, index=momentos).dropna()
    s = s[~s.index.isna()].sort_index()
    pd.DataFrame({'minuto': s.index, 'n': s.values}).to_csv(cache, sep=';',
                                                           index=False)
    return s, linhas


# ==========================================================================
# 2. FRONTEIRAS SEMANAIS
# ==========================================================================

def achar_lacunas(minutos):
    """Lacunas >= LACUNA_FIMSEMANA_H. Devolve (fechamento, abertura, horas)."""
    idx = minutos.index
    difs = idx[1:] - idx[:-1]
    horas = difs.total_seconds() / 3600.0

    saltos = np.where(horas >= LACUNA_FIMSEMANA_H)[0]
    return [(idx[i], idx[i + 1], horas[i]) for i in saltos], horas


def _tod(ts):
    """Hora do dia em horas decimais."""
    return ts.hour + ts.minute / 60.0


# ==========================================================================
# 3. CALENDARIOS CANDIDATOS - datas reais de transicao
# ==========================================================================

def _transicoes_iana(nome, ini, fim):
    """Datas em que o offset UTC do fuso muda, via base IANA."""
    from zoneinfo import ZoneInfo
    tz = ZoneInfo(nome)
    datas, anterior = [], None
    d = ini.date()
    while d <= fim.date():
        off = datetime(d.year, d.month, d.day, 12, tzinfo=tz).utcoffset()
        if anterior is not None and off != anterior:
            datas.append(pd.Timestamp(d))
        anterior = off
        d += timedelta(days=1)
    return datas


def _domingo(ano, mes, n):
    """n-esimo domingo do mes; n negativo conta do fim."""
    if n > 0:
        d = datetime(ano, mes, 1)
        d += timedelta(days=(6 - d.weekday()) % 7 + 7 * (n - 1))
    else:
        d = datetime(ano, mes, 28) + timedelta(days=4)
        d = d.replace(day=1) - timedelta(days=1)      # ultimo dia do mes
        d -= timedelta(days=(d.weekday() + 1) % 7)
    return pd.Timestamp(d.date())


def _transicoes_regra(nome, ini, fim):
    """
    Alternativa quando a base IANA nao esta' instalada (comum no Windows, onde
    o zoneinfo depende do pacote `tzdata`).

    ATENCAO: sao as regras VIGENTES. Calendario civil muda por lei — por isso
    a base IANA e' preferida e o relatorio diz qual das duas foi usada.
    """
    fora = []
    for ano in range(ini.year, fim.year + 1):
        if nome.startswith('Europe'):
            fora += [_domingo(ano, 3, -1), _domingo(ano, 10, -1)]
        elif nome.startswith('America'):
            fora += [_domingo(ano, 3, 2), _domingo(ano, 11, 1)]
    return [d for d in fora if ini <= d <= fim]


def transicoes(nome, ini, fim):
    try:
        return _transicoes_iana(nome, ini, fim), 'IANA'
    except Exception:
        return _transicoes_regra(nome, ini, fim), 'REGRA'


def offset_ny(momento_utc_naive_data):
    """
    Offset de America/New_York em horas na data dada. Usado como ancora para
    converter o fechamento semanal (instante do mundo real) em UTC.
    """
    d = momento_utc_naive_data
    try:
        from zoneinfo import ZoneInfo
        tz = ZoneInfo('America/New_York')
        return datetime(d.year, d.month, d.day, 12,
                        tzinfo=tz).utcoffset().total_seconds() / 3600.0
    except Exception:
        ini = _domingo(d.year, 3, 2)
        fim = _domingo(d.year, 11, 1)
        return -4.0 if ini <= pd.Timestamp(d) < fim else -5.0


# ==========================================================================
# 4. PROGRAMA
# ==========================================================================

def main():
    ap = argparse.ArgumentParser(
        description='Detecta o fuso do servidor a partir do export.')
    ap.add_argument('arquivo', help='Export de ticks ou barras do MT5')
    ap.add_argument('--saida', default=None,
                    help='CSV com a tabela de periodos (opcional)')
    args = ap.parse_args()

    if not os.path.isfile(args.arquivo):
        print('Arquivo nao encontrado: %s' % args.arquivo)
        return 2

    alertas = []

    # ---------------------------------------------------------------- 1
    bloco('1. IDENTIDADE DO ARQUIVO')
    minutos, n_linhas = carregar_minutos(args.arquivo)
    ini, fim = minutos.index[0], minutos.index[-1]
    dias = (fim - ini).total_seconds() / 86400.0

    linha('  arquivo   : %s' % os.path.basename(args.arquivo))
    linha('  registros : %s' % f'{n_linhas:,}')
    linha('  minutos   : %s' % f'{len(minutos):,}')
    linha('  de        : %s  (hora do SERVIDOR)' % ini)
    linha('  ate       : %s  (hora do SERVIDOR)' % fim)
    linha('  cobertura : %.1f dias (~%.1f semanas)' % (dias, dias / 7.0))

    if dias < 28:
        alertas.append('Janela < 4 semanas: nao da' + "'" +
                       ' para observar transicao de horario de verao.')

    # ---------------------------------------------------------------- 2
    bloco('2. DISTRIBUICAO DE LACUNAS (por que 24h separa)')
    lacunas, horas = achar_lacunas(minutos)
    faixas = [(0, 0.5), (0.5, 2), (2, 6), (6, 12), (12, 24),
              (24, 60), (60, 1e9)]
    linha('  %-16s %10s' % ('faixa (horas)', 'ocorrencias'))
    for a, b in faixas:
        n = int(((horas >= a) & (horas < b)).sum())
        rot = '>= %g' % a if b > 1e8 else '%g a %g' % (a, b)
        linha('  %-16s %10s' % (rot, f'{n:,}'))
    linha()
    linha('  A pausa diaria vive na faixa de ~1h; o fim de semana, em ~48h.')
    linha('  O corte de 24h fica no vazio entre as duas, com fator 2 de')
    linha('  margem dos dois lados. Se a tabela acima mostrar massa EM CIMA')
    linha('  de 24h, o corte nao serve para este arquivo — parar e olhar.')

    if not lacunas:
        linha()
        linha('  >>> Nenhuma lacuna de fim de semana. Sem ancora, sem resposta.')
        return 1

    # ---------------------------------------------------------------- 3
    bloco('3. FRONTEIRAS SEMANAIS OBSERVADAS (relogio do SERVIDOR)')
    reg = []
    for fecha, abre, h in lacunas:
        reg.append({
            'fechamento': fecha, 'abertura': abre, 'lacuna_h': h,
            'fec_dow': fecha.day_name()[:3], 'abr_dow': abre.day_name()[:3],
            'fec_tod': _tod(fecha), 'abr_tod': _tod(abre),
        })
    df = pd.DataFrame(reg)

    # fim de semana normal: fecha sex/sab, reabre dom/seg, ~40-56h de lacuna
    df['normal'] = (df['fec_dow'].isin(['Fri', 'Sat']) &
                    df['abr_dow'].isin(['Sun', 'Mon']) &
                    df['lacuna_h'].between(40, 56))

    linha('  %-19s %-5s %7s  %-19s %-5s %7s %8s %s' %
          ('fechamento', 'dia', 'hora', 'abertura', 'dia', 'hora',
           'lacuna', ''))
    for _, r in df.iterrows():
        linha('  %-19s %-5s %7.2f  %-19s %-5s %7.2f %8.1f %s' %
              (r['fechamento'], r['fec_dow'], r['fec_tod'],
               r['abertura'], r['abr_dow'], r['abr_tod'], r['lacuna_h'],
               '' if r['normal'] else '<-- ATIPICA'))

    n_atip = int((~df['normal']).sum())
    if n_atip:
        alertas.append('%d fronteira(s) atipica(s) — provavel feriado. '
                       'Excluidas da deteccao de transicao.' % n_atip)
    linha()
    linha('  Fronteiras atipicas sao EXCLUIDAS do passo seguinte: semana de')
    linha('  feriado desloca a fronteira e viraria falso positivo.')

    limpo = df[df['normal']].reset_index(drop=True)
    if len(limpo) < 3:
        linha()
        linha('  >>> Menos de 3 fronteiras limpas. Evidencia insuficiente.')
        return 1

    # --------------------------------------------------------------- 3b
    bloco('3b. OFFSET POR SEMANA (calculado ANTES de procurar transicao)')
    linha('  A hora BRUTA da fronteira se move quando NOVA YORK troca de DST:')
    linha('  o ancora se desloca, nao o servidor. Procurar transicao na hora')
    linha('  bruta confunde as duas coisas — foi o que fez a v1.00 declarar')
    linha('  "nenhum candidato bate" num arquivo em que o servidor simplesmente')
    linha('  nao muda. Transicao DO SERVIDOR e' + "'" + ' salto no OFFSET, que ja' + "'")
    linha('  desconta o DST de Nova York.')
    linha()
    _br = []
    for _, r in limpo.iterrows():
        e = r['fec_tod'] - (17.0 - offset_ny(r['fechamento']))
        _br.append(((e + 12) % 24) - 12)
    _br = np.array(_br)
    _res = float(np.median(_br - np.round(_br)))
    off_sem = np.round(_br - _res).astype(int)
    linha('  offset por semana: %s' % ', '.join('%+d' % i for i in off_sem))
    linha('  residuo mediano  : %+.1f min' % (_res * 60))

    # ---------------------------------------------------------------- 4
    bloco('4. TRANSICOES DETECTADAS (no OFFSET do servidor)')
    base = pd.Series(off_sem.astype(float))
    saltos = []
    for i in range(1, len(limpo)):
        d = base.iloc[i] - base.iloc[i - 1]
        if d > 12:
            d -= 24                      # cruzou a meia-noite
        elif d < -12:
            d += 24
        if abs(d) >= 0.5:
            # confirmacao: o novo patamar precisa PERSISTIR
            # Um salto REAL separa DOIS patamares. Exigir estabilidade so'
            # DEPOIS deixa passar o retorno de uma excursao de uma semana:
            # sexta truncada por falha de feed cai, volta, e a VOLTA parece
            # "confirmada" porque dali em diante tudo e' estavel. Medido em
            # 2026-08-20: 2026-06-19 e 2026-07-03 fecham 4h cedo (lacuna 53h
            # contra 49h) e o retorno em 2026-07-10 era declarado transicao.
            antes = base.iloc[max(0, i - SEMANAS_CONFIRMACAO):i]
            resto = base.iloc[i:i + SEMANAS_CONFIRMACAO]
            persiste = (len(resto) >= SEMANAS_CONFIRMACAO and
                        (resto.max() - resto.min()) < 0.5 and
                        len(antes) >= SEMANAS_CONFIRMACAO and
                        (antes.max() - antes.min()) < 0.5)
            saltos.append({
                'data': limpo['fechamento'].iloc[i],
                'delta_h': d,
                'de': base.iloc[i - 1], 'para': base.iloc[i],
                'confirmado': persiste,
            })

    if not saltos:
        linha('  Nenhuma transicao no OFFSET: o relogio do servidor NAO mudou')
        linha('  nesta janela.')
        linha()
        linha('  Isso e' + "'" + ' informacao POSITIVA, nao ausencia de medicao: se a')
        linha('  janela contem a data de virada de um calendario candidato e o')
        linha('  offset NAO saltou nela, esse calendario fica EXCLUIDO — o')
        linha('  servidor nao o segue. Ver secao 5.')
    else:
        for s in saltos:
            rot = ('CONFIRMADA' if s['confirmado'] else
                   'NAO confirmada (patamar instavel) — tratar como suspeita')
            if abs(abs(s['delta_h']) - 1.0) > 0.25:
                rot += (" | NAO EH DST: salto de %+.0fh; horario de verao eh +-1h"
                        % s['delta_h'])
            linha('  %s  %+.2f h  (%.2f -> %.2f)  %s' %
                  (s['data'].date(), s['delta_h'], s['de'], s['para'], rot))

    # ---------------------------------------------------------------- 5
    bloco('5. IDENTIFICACAO DO CALENDARIO')
    candidatos = ['Europe/London', 'Europe/Berlin', 'America/New_York',
                  'Australia/Sydney', 'Pacific/Auckland']
    fonte = None
    linha('  %-20s %-34s %s' % ('calendario', 'transicoes previstas', 'bate?'))
    conf = [s for s in saltos if s['confirmado']]
    compat = []
    for nome in candidatos:
        datas, fonte = transicoes(nome, ini, fim)
        prev = ', '.join(str(d.date()) for d in datas) or '(nenhuma)'
        if not conf:
            # Sem salto no offset, todo candidato que VIRA dentro da janela
            # fica excluido: se o servidor o seguisse, teria saltado junto.
            veredito = ('EXCLUIDO (virou na janela, offset nao saltou)'
                        if datas else '- (nao vira nesta janela)')
        else:
            ok = all(any(abs((pd.Timestamp(s['data'].date()) - d).days) <= 7   # semanal: a virada de domingo so' aparece na sexta
                         for d in datas) for s in conf) and \
                 len(datas) == len(conf)
            veredito = 'SIM' if ok else 'nao'
            if ok:
                compat.append(nome)
        linha('  %-20s %-34s %s' % (nome, prev[:34], veredito))

    linha()
    linha('  Base de calendario usada: %s' % fonte)
    if fonte == 'REGRA':
        alertas.append('Base IANA indisponivel (instalar `tzdata`). Foram '
                       'usadas as REGRAS VIGENTES de DST — calendario civil '
                       'muda por lei; conferir se a janela e' + "'" + ' antiga.')

    if not conf:
        excl = [n for n in candidatos if transicoes(n, ini, fim)[0]]
        if excl:
            linha()
            linha('  >>> SERVIDOR COM OFFSET FIXO nesta janela.')
            linha('      Excluidos por terem virado sem que o offset saltasse:')
            for n in excl:
                linha('        - %s' % n)
            linha('      O deslocamento visivel na hora BRUTA da fronteira e' + "'")
            linha('      o DST de NOVA YORK (o ancora), nao do servidor.')
    if compat:
        linha('  Compativel com: %s' % ', '.join(compat))
        linha('  Europe/London e Europe/Berlin viram no MESMO instante e sao')
        linha('  indistinguiveis pela data. O que as separa e' + "'" +
              ' o offset absoluto')
        linha('  da secao 6.')
    elif conf:
        linha('  >>> NENHUM candidato bate. Servidor com regra propria, ou')
        linha('      mudanca de fuso/migracao no meio da janela. Investigar.')
        alertas.append('Transicao observada nao corresponde a nenhum '
                       'calendario candidato.')

    # ---------------------------------------------------------------- 6
    bloco('6. OFFSET ABSOLUTO (ancora: fechamento semanal em Nova York)')
    linha('  Metodo: o fechamento semanal e' + "'" +
          ' um instante do mundo real, num')
    linha('  horario LOCAL fixo de Nova York (convencao CME/COMEX: 17:00).')
    linha('  Convertendo esse instante para UTC na data de cada semana e')
    linha('  subtraindo da hora observada no servidor, sobra o offset.')
    linha()
    linha('  A CONVENCAO 17:00 NAO E' + "'" + ' ASSUMIDA COMO VERDADE: ela entra,')
    linha('  e o RESIDUO em minutos e' + "'" + ' reportado. Corretora que fecha')
    linha('  16:55 aparece como residuo de -5 min, nao como offset errado.')
    linha()

    brutos = []
    for _, r in limpo.iterrows():
        d = r['fechamento']
        utc_1700 = 17.0 - offset_ny(d)          # 17:00 NY -> hora UTC
        est = r['fec_tod'] - utc_1700
        est = ((est + 12) % 24) - 12            # normaliza para -12..+12
        brutos.append(est)
    brutos = np.array(brutos)

    # o offset de corretora e' inteiro; o desvio fracionario COMUM a todas as
    # semanas e' o horario proprio da corretora, nao erro de medida.
    residuo = float(np.median(brutos - np.round(brutos)))
    corrig = brutos - residuo
    inteiros = np.round(corrig).astype(int)
    disp = float(np.max(np.abs(corrig - inteiros))) if len(corrig) else 0.0

    linha('  offset bruto por semana : %s' %
          ', '.join('%+.2f' % b for b in brutos))
    linha('  residuo mediano         : %+.1f min  (desvio da corretora vs 17:00 NY)'
          % (residuo * 60))
    linha('  offset corrigido        : %s' %
          ', '.join('%+d' % i for i in inteiros))
    linha('  maior desvio ao inteiro : %.1f min' % (disp * 60))
    linha()
    if disp > 0.25:
        linha('  >>> Desvio acima de 15 min. O offset NAO fecha em hora cheia:')
        linha('      ou a ancora nao vale para este simbolo, ou ha' + "'" +
              ' fronteira')
        linha('      irregular. NAO usar o numero — investigar primeiro.')
        alertas.append('Offset nao converge para hora cheia (desvio %.1f min).'
                       % (disp * 60))
    else:
        linha('  Offset fecha em hora cheia: a ancora e' + "'" +
              ' consistente com o dado.')

    # ---------------------------------------------------------------- 7
    bloco('7. VERIFICACAO INDEPENDENTE (perfil de atividade por hora)')
    linha('  Evidencia que NAO usa a lacuna: se o perfil de ticks por hora')
    linha('  desliza 1h na mesma semana em que a fronteira pulou, sao duas')
    linha('  medidas independentes apontando para o mesmo lado.')
    linha()

    tmp = pd.DataFrame({'n': minutos.values}, index=minutos.index)
    tmp['sem'] = tmp.index.to_period('W')
    tmp['h'] = tmp.index.hour
    mat = tmp.pivot_table(index='sem', columns='h', values='n',
                          aggfunc='sum').fillna(0.0)
    mat = mat.div(mat.sum(axis=1), axis=0)          # normaliza cada semana

    linha('  %-14s %s' % ('semana', 'deslocamento vs semana anterior'))
    desloc = {}
    for i in range(1, len(mat)):
        a = mat.iloc[i - 1].reindex(range(24), fill_value=0.0).values
        b = mat.iloc[i].reindex(range(24), fill_value=0.0).values
        corr = [float(np.dot(b, np.roll(a, k))) for k in range(-3, 4)]
        k = range(-3, 4)[int(np.argmax(corr))]
        desloc[str(mat.index[i])] = k
        if k != 0:
            linha('  %-14s %+d h' % (str(mat.index[i]), k))
    if all(v == 0 for v in desloc.values()):
        linha('  (nenhum deslocamento detectado no perfil)')

    linha()
    if conf:
        for s in conf:
            sem = str(pd.Period(s['data'], freq='W'))
            k = desloc.get(sem, 0)
            bate = (k != 0 and np.sign(k) == np.sign(s['delta_h']))
            linha('  transicao %s: perfil %s' %
                  (s['data'].date(),
                   'CONFIRMA (%+d h)' % k if bate else
                   'NAO confirma — duas medidas discordando, investigar'))
            if not bate:
                alertas.append('Transicao em %s nao confirmada pelo perfil '
                               'de atividade.' % s['data'].date())

    # ---------------------------------------------------------------- 8
    bloco('8. TABELA DE PERIODOS (saida principal)')
    cortes = [ini] + [s['data'] for s in conf] + [fim]
    per = []
    for i in range(len(cortes) - 1):
        a, b = cortes[i], cortes[i + 1]
        sel = (limpo['fechamento'] >= a) & (limpo['fechamento'] <= b)
        vals = inteiros[sel.values] if sel.any() else np.array([])
        if len(vals) == 0:
            continue
        modo = int(pd.Series(vals).mode().iloc[0])
        fora = int((vals != modo).sum())
        if compat:
            cal = '|'.join(compat)
        elif not conf and [n for n in candidatos if transicoes(n, ini, fim)[0]]:
            # Nenhum salto de offset e ha' candidato que virou na janela:
            # a conclusao NAO e' "nao identificado", e' "nao segue nenhum".
            cal = 'OFFSET FIXO (candidatos excluidos)'
        else:
            cal = 'NAO IDENTIFICADO'
        per.append({
            'inicio': a, 'fim': b,
            'offset_h': modo,
            'n_semanas': int(len(vals)),
            'semanas_fora_do_modo': fora,
            'estavel': bool(fora == 0),
            'calendario': cal,
        })
    tab = pd.DataFrame(per)

    if tab.empty:
        linha('  Sem periodos estimaveis.')
    else:
        linha('  %-19s %-19s %8s %10s %6s %9s %s' %
              ('inicio', 'fim', 'offset', 'n_semanas', 'fora', 'estavel',
               'calendario'))
        for _, r in tab.iterrows():
            linha('  %-19s %-19s %+8d %10d %6d %9s %s' %
                  (r['inicio'], r['fim'], r['offset_h'], r['n_semanas'],
                   r['semanas_fora_do_modo'],
                   'sim' if r['estavel'] else 'NAO', r['calendario']))
        if (tab['semanas_fora_do_modo'] > 0).any():
            linha()
            linha('  `fora` conta semanas cujo offset difere do modo. Conferir se')
            linha('  sao mudanca de relogio ou FALHA DE DADO: sexta que fecha')
            linha('  cedo por feed truncado aparece aqui e nao e' + "'" + ' fuso.')
        if args.saida:
            tab.to_csv(args.saida, index=False, sep=';')
            linha()
            linha('  Tabela gravada em: %s' % args.saida)

    # ---------------------------------------------------------------- 9
    bloco('9. ALERTAS')
    if alertas:
        for a in alertas:
            linha('  [!] ' + a)
    else:
        linha('  Nenhum.')

    # --------------------------------------------------------------- 10
    bloco('10. LIMITACOES — leem-se JUNTO do numero, nao depois')
    linha('  - O offset vale para a JANELA MEDIDA. Extrapolar para fora dela')
    linha('    e' + "'" + ' hipotese, nao medicao. Sem transicao observada, o')
    linha('    calendario nao foi identificado e nao ha' + "'" +
          ' base para extrapolar.')
    linha('  - A ancora e' + "'" + ' o fechamento SEMANAL. Simbolo com agenda')
    linha('    propria (indice, cripto) pode nao respeitar essa fronteira.')
    linha('  - Feriado desloca a fronteira. As atipicas foram excluidas, mas')
    linha('    feriado longo pode mascarar uma transicao real vizinha.')
    linha('  - Este script CALIBRA, nao decide. O offset entra na analise como')
    linha('    coluna por barra; nenhum limiar de sessao vira default aqui.')
    linha('  - **ESCOPO: este script mede o relogio do ARQUIVO, nao o do EA.**')
    linha('    Se o exportador normalizar o timestamp na gravacao, o resultado')
    linha('    NAO descreve o relogio que o EA le em TimeCurrent(). Isso e' + "'")
    linha('    limitacao de escopo, nao defeito. Para amarrar os dois e' + "'"
          + ' preciso')
    linha('    evidencia independente — perfil horario do CSV do EA contra o do')
    linha('    arquivo, ou um EA de diagnostico imprimindo TimeCurrent().')
    linha('  - Feriado com fechamento antecipado NAO e' + "'" + ' falha de dado.')
    linha('    Medido em 2026-08-20: 2026-06-19 (Juneteenth) e 2026-07-03 (4 de')
    linha('    julho observado) fecham 16:59 = 13:00 ET, que e' + "'" + ' o fechamento')
    linha('    antecipado da CME. Antes de chamar de truncamento, conferir a')
    linha('    data contra o calendario de feriados.')
    linha('  - Perfil reconstruido (armadilha 13) NAO e' + "'" +
          ' detectado por este')
    linha('    teste: fuso correto e caminho de bid fabricado convivem. Rodar')
    linha('    S-Py-Perfil_Spread.py em separado.')

    return 0


if __name__ == '__main__':
    sys.exit(main())
