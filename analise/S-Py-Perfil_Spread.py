# -*- coding: utf-8 -*-
# =====================================================================
# S-Py-Perfil_Spread.py
# PASTA:    analise\
# RODAR EM: qualquer maquina com Python 3 + pandas + numpy
# USO:      python S-Py-Perfil_Spread.py <export_de_ticks.csv> [--limite N] [--rotulo TEXTO]
# ENTRADA:  export de ticks do MT5 (Simbolos > Ticks > Exportar barras/ticks),
#           separador TAB, colunas <DATE> <TIME> <BID> <ASK> <LAST> <VOLUME> <FLAGS>
# ---------------------------------------------------------------------
# POR QUE EXISTE
# Comparar conta Standard com Raw/Pro so' vale se o custo de cada uma for
# MEDIDO na mesma janela, tick a tick. Spread de tabela de corretora e'
# propaganda; spread de export de tick e' o que a conta cobrou.
#
# O QUE RESPONDE
#  1. Distribuicao do spread em PONTOS (p1..p99.9) - exata, via histograma
#     inteiro, nao amostra.
#  2. Autenticidade do feed, POR MES, por dois testes:
#     (a) valores DISTINTOS de spread — sinal fraco sozinho: uma corretora
#         pode quotar spread quantizado (poucos degraus) e ainda assim ser
#         mercado real;
#     (b) TROCAS de valor por milhao de ticks — este e' o discriminador.
#         Feed real muda de degrau o tempo todo (milhares por milhao de
#         ticks) e alarga em evento. Spread carimbado no dado nao muda.
#         Medido em 2026-08-18 no XAUUSD da Exness-MT5Real3: julho deu
#         ~3.200 trocas/1M ticks (real); janeiro deu 2,5 trocas/1M ao longo
#         de 4 dias corridos (constante, dado inutilizavel).
#  3. Taxa de aprovacao do filtro `spread <= 260` da estrategia titular.
#     Numa conta de spread apertado esse corte aprova ~tudo: o filtro morre,
#     e com ele a melhor configuracao ja' medida (ret/DD 26,6x).
#     Ver CLAUDE.md secao 5.3 e fila item 6.
#  4. AUTENTICIDADE DO CAMINHO DO BID (v1.03) — mediana de |dbid| por tick e
#     ticks por minuto, por mes. Este teste NAO toca no ask: pega tick
#     RECONSTRUIDO a partir de barra M1, que preserva OHLC (e portanto
#     MFE/MAE de barra) mas inventa o caminho intraminuto. Como 63% dos
#     trades saem por breakeven intrabar, e' o unico canal que importa.
#     Medido em 2026-08-19 nas janelas de 75 ticks do EA de medicao:
#     XAUUSDm 2026-01 deu 43,1 pts/tick contra 97-108 nos outros meses,
#     invariante a ATR e hora. Aqui a mesma medida sai da FONTE.
#  5. Quebra por mes (com o teste de autenticidade) e por hora do servidor.
#
# NAO responde: custo total da conta. Raw/Zero cobra COMISSAO por lote, que
# NAO aparece no export de ticks. Custo round-trip = spread + comissao.
# Comparar contas so' pelo spread favorece a Raw artificialmente.
#
# CHANGELOG
#   1.03  2026-08-19  CAMINHO DO BID: mediana de |dbid| por tick e ticks/min
#                     por mes. O teste de spread (trocas/1M) so' enxerga o
#                     canal do ASK; um feed reconstruido de barra M1 pode ter
#                     spread plausivel e caminho de BID sintetico. Foi esse o
#                     caso de 2026-01, e nenhum teste anterior o pegava.
#   1.02  2026-08-18  Teste de TROCAS por mes. A contagem de valores distintos
#                     sozinha acusava spread quantizado real como sintetico —
#                     falso positivo. Trocas/1M separa os dois casos.
#   1.01  2026-08-18  Histograma POR MES: p50/p90, valores distintos e share
#                     do valor dominante. Sem isso um mes de tick sintetico
#                     se esconde dentro da media geral.
#   1.00  2026-08-18  Primeira versao.
# =====================================================================
import sys
import numpy as np
import pandas as pd

PONTO = 0.001          # XAUUSD 3 digitos
MAX_PTS = 100000       # teto do histograma
CORTE_FILTRO = 260     # filtro de spread da estrategia titular


def linha(t=''):
    print(t)


def bloco(titulo):
    print()
    print('=' * 74)
    print(titulo)
    print('=' * 74)


def pctl(hist, q):
    """Percentil exato a partir do histograma."""
    total = hist.sum()
    if total == 0:
        return -1
    return int(np.searchsorted(np.cumsum(hist), q * total))


def main():
    if len(sys.argv) < 2:
        print('USO: python S-Py-Perfil_Spread.py <export_de_ticks.csv> [--limite N] [--rotulo TEXTO]')
        sys.exit(1)

    caminho = sys.argv[1]
    limite = None
    rotulo = caminho
    if '--limite' in sys.argv:
        limite = int(sys.argv[sys.argv.index('--limite') + 1])
    if '--rotulo' in sys.argv:
        rotulo = sys.argv[sys.argv.index('--rotulo') + 1]

    hist = np.zeros(MAX_PTS + 1, dtype=np.int64)
    hist_mes = {}    # 'YYYY.MM' -> histograma
    trocas_mes = {}  # 'YYYY.MM' -> quantas vezes o spread mudou de valor
    por_hora = {}    # 'HH' -> [soma, n]
    passo_mes = {}   # 'YYYY.MM' -> histograma de |dbid| em pontos [v1.03]
    minutos_mes = {} # 'YYYY.MM' -> set de 'DD HH:MM' com pelo menos 1 tick
    n_lidos = n_validos = n_sem_ask = n_negativo = n_fora = 0
    data_min = data_max = None
    sp_anterior = None   # ultimo spread do chunk anterior (continuidade)
    bid_anterior = None  # ultimo bid do chunk anterior [v1.03]

    leitor = pd.read_csv(
        caminho, sep='\t', engine='c',
        usecols=['<DATE>', '<TIME>', '<BID>', '<ASK>'],
        dtype={'<DATE>': 'string', '<TIME>': 'string',
               '<BID>': 'float64', '<ASK>': 'float64'},
        chunksize=4_000_000,
    )

    for ch in leitor:
        n_lidos += len(ch)

        bid = ch['<BID>'].to_numpy()
        ask = ch['<ASK>'].to_numpy()
        ok = np.isfinite(bid) & np.isfinite(ask) & (bid > 0) & (ask > 0)
        n_sem_ask += int((~ok).sum())

        if ok.any():
            sp_all = np.rint((ask[ok] - bid[ok]) / PONTO).astype(np.int64)
            mes_all = ch['<DATE>'].to_numpy()[ok].astype('U7')
            hora_all = ch['<TIME>'].to_numpy()[ok].astype('U2')

            n_negativo += int((sp_all < 0).sum())
            dentro = (sp_all >= 0) & (sp_all <= MAX_PTS)
            n_fora += int((~dentro).sum())
            sp = sp_all[dentro]
            mes = mes_all[dentro]
            hora = hora_all[dentro]

            hist += np.bincount(sp, minlength=MAX_PTS + 1)
            n_validos += len(sp)

            for m in np.unique(mes):
                h = hist_mes.setdefault(m, np.zeros(MAX_PTS + 1, dtype=np.int64))
                h += np.bincount(sp[mes == m], minlength=MAX_PTS + 1)

            # Trocas de valor. O arquivo e' cronologico, entao basta comparar
            # cada tick com o anterior; a troca conta no mes do tick posterior.
            if len(sp):
                if sp_anterior is not None and sp[0] != sp_anterior:
                    trocas_mes[mes[0]] = trocas_mes.get(mes[0], 0) + 1
                idx = np.nonzero(sp[1:] != sp[:-1])[0] + 1
                for m, c in zip(*np.unique(mes[idx], return_counts=True)):
                    trocas_mes[m] = trocas_mes.get(m, 0) + int(c)
                sp_anterior = int(sp[-1])
            for hh in np.unique(hora):
                sel = sp[hora == hh]
                a = por_hora.setdefault(hh, [0, 0])
                a[0] += int(sel.sum()); a[1] += len(sel)

            # [v1.03] CAMINHO DO BID. Passo absoluto entre ticks consecutivos
            # VALIDOS, em pontos. O passo pertence ao mes do tick posterior.
            # bid_anterior costura a fronteira entre chunks.
            bidv = bid[ok][dentro]
            if len(bidv):
                if bid_anterior is not None:
                    bidv = np.concatenate(([bid_anterior], bidv))
                    mes_p = mes
                else:
                    mes_p = mes[1:]
                passo = np.rint(np.abs(np.diff(bidv)) / PONTO).astype(np.int64)
                passo = np.minimum(passo, MAX_PTS)
                for m in np.unique(mes_p):
                    h = passo_mes.setdefault(m, np.zeros(MAX_PTS + 1, dtype=np.int64))
                    h += np.bincount(passo[mes_p == m], minlength=MAX_PTS + 1)
                bid_anterior = float(bidv[-1])

            # minutos distintos com tick, para ticks/min por mes
            data_c = ch['<DATE>'].to_numpy()[ok][dentro]
            hm = ch['<TIME>'].to_numpy()[ok][dentro].astype('U5')
            chave = np.char.add(np.char.add(data_c.astype('U10'), ' '), hm)
            for m in np.unique(mes):
                minutos_mes.setdefault(m, set()).update(chave[mes == m].tolist())

        d = ch['<DATE>'].dropna()
        if len(d):
            lo, hi = d.iloc[0], d.iloc[-1]
            data_min = lo if data_min is None else min(data_min, lo)
            data_max = hi if data_max is None else max(data_max, hi)

        print('  ... %d ticks lidos' % n_lidos, file=sys.stderr)
        if limite is not None and n_lidos >= limite:
            break

    total = int(hist.sum())
    if total == 0:
        print('Nenhum tick valido lido.')
        sys.exit(1)

    bloco('PERFIL DE SPREAD - %s' % rotulo)
    linha('Arquivo        : %s' % caminho)
    linha('Periodo        : %s -> %s' % (data_min, data_max))
    linha('Ticks lidos    : %s' % f'{n_lidos:,}')
    linha('Ticks validos  : %s  (bid e ask > 0)' % f'{n_validos:,}')
    linha('Sem bid/ask    : %s' % f'{n_sem_ask:,}')
    if n_negativo:
        linha('SPREAD NEGATIVO: %s  <- anomalia, investigar' % f'{n_negativo:,}')
    if n_fora:
        linha('FORA DO TETO   : %s' % f'{n_fora:,}')

    bloco('1. DISTRIBUICAO DO SPREAD (pontos; 1 pt = $0.001 com 0.01 lote)')
    for q in (0.01, 0.10, 0.25, 0.50, 0.75, 0.90, 0.99, 0.999):
        v = pctl(hist, q)
        linha('  p%-6s %7d pts   = $%.3f por 0.01 lote (round-trip, sem comissao)'
              % (('%g' % (q * 100)), v, v * 0.001))
    media = float((np.arange(MAX_PTS + 1) * hist).sum()) / total
    linha('  media   %7.1f pts   = $%.3f' % (media, media * 0.001))
    linha('  min     %7d pts' % int(np.argmax(hist > 0)))
    linha('  max     %7d pts' % int(MAX_PTS - np.argmax(hist[::-1] > 0)))

    bloco('2. AUTENTICIDADE DOS TICKS - valores distintos de spread')
    distintos = int((hist > 0).sum())
    linha('  Total: %d valores distintos em %s ticks.' % (distintos, f'{total:,}'))
    linha('  Os 12 mais frequentes (pts : %% dos ticks):')
    for v in np.argsort(hist)[::-1][:12]:
        if hist[v] == 0:
            continue
        linha('    %6d pts : %5.2f%%' % (v, 100.0 * hist[v] / total))

    bloco('3. POR MES - distribuicao E teste de autenticidade')
    linha('  %-9s %13s %6s %6s %8s %11s %12s'
          % ('mes', 'ticks', 'p50', 'p90', 'distint', 'dominante', 'trocas/1M'))
    linha('  ' + '-' * 72)
    taxas = [trocas_mes.get(m, 0) * 1e6 / int(hist_mes[m].sum()) for m in hist_mes]
    mediana_trocas = float(np.median(taxas)) if taxas else 0.0
    for m in sorted(hist_mes):
        h = hist_mes[m]
        n = int(h.sum())
        dom = int(np.argmax(h))
        tr = trocas_mes.get(m, 0)
        # Corte RELATIVO: mes uma ordem de grandeza abaixo da mediana dos meses.
        # NAO CALIBRADO — serve para chamar atencao, nao para decidir sozinho.
        # Sempre confirmar olhando um trecho contiguo do mes suspeito.
        marca = '  <<< SUSPEITO' if (tr * 1e6 / n) < 0.1 * mediana_trocas else ''
        linha('  %-9s %13s %6d %6d %8d %5d=%4.1f%% %12.0f%s'
              % (m, f'{n:,}', pctl(h, 0.50), pctl(h, 0.90), int((h > 0).sum()),
                 dom, 100.0 * h[dom] / n, tr * 1e6 / n, marca))
    linha()
    linha('  LEITURA — o discriminador e' + "'" + ' TROCAS/1M, nao a contagem de distintos.')
    linha('  Mediana dos meses: %.0f trocas/1M. Um mes muito abaixo disso tem' % mediana_trocas)
    linha('  spread praticamente CARIMBADO no dado: o custo intrabar vira uma')
    linha('  constante e o breakeven nunca derrapa. Backtest path-dependent nesse')
    linha('  mes e' + "'" + ' INVALIDO, nao apenas impreciso — descartar o periodo.')
    linha('  Poucos valores distintos COM muitas trocas = spread quantizado real')
    linha('  (a corretora quota em degraus e alarga em evento). Isso e' + "'" + ' usavel,')
    linha('  mas como SENSOR de condicao de mercado tem resolucao baixa.')

    bloco('4. AUTENTICIDADE DO CAMINHO DO BID (nao toca no ask)')
    linha('  %-9s %13s %11s %11s %11s %11s'
          % ('mes', 'ticks', 'passo p50', 'passo p90', 'ticks/min', 'pts/min'))
    linha('  ' + '-' * 72)
    p50s = {}
    for m in sorted(passo_mes):
        h = passo_mes[m]
        n = int(h.sum())
        if n == 0:
            continue
        nmin = max(1, len(minutos_mes.get(m, ())))
        tpm = n / nmin
        p50 = pctl(h, 0.50)
        p50s[m] = p50
        linha('  %-9s %13s %11d %11d %11.1f %11.0f'
              % (m, f'{n:,}', p50, pctl(h, 0.90), tpm, p50 * tpm))
    if len(p50s) >= 3:
        med = float(np.median(list(p50s.values())))
        linha()
        for m in sorted(p50s):
            if med > 0 and p50s[m] < 0.6 * med:
                linha('  >>> %s: passo %d pts = %.2fx a mediana dos meses (%.0f).'
                      % (m, p50s[m], p50s[m] / med, med))
                linha('      Assinatura de TICK RECONSTRUIDO de barra M1: o mesmo')
                linha('      movimento partido em mais passos, menores. Preserva OHLC')
                linha('      (MFE/MAE de barra ficam normais) e INVENTA o caminho')
                linha('      intraminuto — que e' + "'" + ' onde o breakeven e o stop vivem.')
                linha('      Mes INVALIDO para desenho path-dependent, e NAO recuperavel')
                linha('      re-precificando: modelo de spread conserta o ask, nao o bid.')
    linha()
    linha('  LEITURA — este teste e' + "'" + ' independente do de spread e pega o que ele')
    linha('  nao pega. Um feed reconstruido pode ter spread plausivel e caminho')
    linha('  de bid sintetico. Confirmar sempre olhando a coluna pts/min: se ela')
    linha('  bate com os outros meses mas o passo nao, e' + "'" + ' o caminho que foi')
    linha('  fabricado, nao a volatilidade que mudou.')

    bloco('5. FILTRO `spread <= %d` DA ESTRATEGIA TITULAR' % CORTE_FILTRO)
    passa = int(hist[:CORTE_FILTRO + 1].sum())
    pct = 100.0 * passa / total
    linha('  Aprovaria %s de %s ticks = %.2f%%' % (f'{passa:,}', f'{total:,}', pct))
    if pct > 99.0:
        linha('  >>> O filtro aprova praticamente tudo NESTA conta: deixa de filtrar.')
        linha('      A melhor config medida (ret/DD 26,6x, PF 5,83) DEPENDE dele —')
        linha('      e o projeto ja' + "'" + ' mediu que 99%% do efeito e' + "'" + ' condicao de mercado,')
        linha('      nao custo. Antes de comparar contas, re-expressar o corte em')
        linha('      termos RELATIVOS (percentil da propria conta, ou multiplo de ATR).')

    bloco('6. POR HORA DO SERVIDOR (media de spread)')
    linha('  %-5s %13s %10s' % ('hora', 'ticks', 'media pts'))
    for h in sorted(por_hora):
        s, n = por_hora[h]
        linha('  %-5s %13s %10.1f' % (h, f'{n:,}', float(s) / n))

    bloco('LEMBRETE')
    linha('  Este relatorio mede SPREAD, nao custo total.')
    linha('  Conta Raw/Zero cobra COMISSAO por lote, ausente do export de ticks.')
    linha('  Custo round-trip = spread + comissao. Sem a comissao medida na')
    linha('  especificacao do simbolo, comparar contas pelo spread sozinho')
    linha('  favorece a Raw artificialmente.')


if __name__ == '__main__':
    main()
