#===============================================================================
# S-Py-Retrato_Sensores.py
#
# PASTA: C:\dev\SBurn\analise\
# COMPILA? Nao (script Python 3).
#
# O QUE FAZ
#   Primeiro retrato das familias de sensores gravadas pelo
#   S-EA-Test_ConsistencyGate e nunca analisadas: liquidez, Supertrend,
#   calendario/sessoes, alternativas ao ATR, estrutura no M5 e posicao/zona.
#
#   Para cada sensor, separa os sinais em dois grupos e mede a ASSIMETRIA
#   (medMFE - medMAE, em pontos) na Entrada A, nos horizontes 5/15/30 barras.
#
# PRE-REGISTRO (R2) - escrito ANTES de rodar
#   Hipotese: os sinais que o sensor marca como favoraveis tem assimetria
#   maior que os desfavoraveis.
#   Criterio de ACHADO, as tres condicoes juntas:
#     (a) diferenca de assimetria > custo (spread mediano 260 pts);
#     (b) mesmo sinal nos TRES horizontes;
#     (c) presente em >= 5 dos 7 meses.
#   Uma ou duas condicoes = hipotese para pre-registrar, nunca achado.
#   O criterio (c) existe porque concentracao mensal ja' enganou este projeto.
#
# LIMITES (R3)
#   - Assimetria e' condicao NECESSARIA, nao suficiente (secao 4 do CLAUDE.md).
#   - MFE e' excursao maxima, nao lucro, e nao diz a ORDEM dos eventos.
#   - Isto e' caracterizacao exploratoria de 568 sinais em 6,5 meses. Nada aqui
#     promove hipotese: promocao exige OOS e estabilidade mensal.
#
# USO
#   python analise\S-Py-Retrato_Sensores.py <csv do gate>
#   (sem argumento, procura o mais recente em Common\Files\SBurn)
#
# CHANGELOG
#   1.00  2026-08-19  Primeira versao.
#===============================================================================
import glob
import os
import sys

import pandas as pd

CUSTO_PTS = 260.0          # spread mediano medido, secao 3 do CLAUDE.md
CUSTO_ATR = None           # calculado do proprio dado: 260 pts / ATR mediano
HORIZONTES = [5, 15, 30]   # barras do TF do grafico
MIN_GRUPO = 40             # abaixo disso o grupo nao sustenta mediana

# Familias a retratar. Cada entrada: (rotulo, colunas).
FAMILIAS = [
    ("liquidez",        ["liq_round", "liq_r50", "liq_pdh", "liq_pdl", "liq_frac"]),
    ("supertrend",      ["st_local", "st_regime", "st_acordo"]),
    ("calendario",      ["cal_asia", "cal_lon", "cal_ny", "cal_dow", "cal_1abarra"]),
    ("vol (alt ao ATR)", ["vol_std", "vol_yz", "vol_medr", "vol_eff"]),
    ("estrutura M5",    ["est_micro", "est_macro", "est_acordo"]),
    ("posicao / zona",  ["zpos", "bs_below", "bs_above", "pac_w"]),
]


def acha_csv(arg):
    if arg:
        return arg
    base = os.path.join(os.environ.get("APPDATA", ""), "MetaQuotes",
                        "Terminal", "Common", "Files", "SBurn")
    cands = glob.glob(os.path.join(base, "test_consistgate_*.csv"))
    if not cands:
        sys.exit("nenhum CSV do gate encontrado")
    return max(cands, key=os.path.getmtime)


def assimetria(df, h, em_atr=True):
    """medMFE - medMAE no horizonte h, Entrada A.

    em_atr=True normaliza por atr_ent. E' o DEFAULT porque assimetria em
    PONTOS premia volatilidade por construcao: grupo mais volatil tem MFE
    maior E MAE maior, e a diferenca cresce so' por escala. Medir a familia
    `vol` em pontos daria "achado" em todos os quatro sensores - seria
    artefato de unidade, nao vantagem.
    """
    mfe, mae = "mfe%d_A" % h, "mae%d_A" % h
    if mfe not in df.columns or mae not in df.columns or df.empty:
        return None
    if not em_atr or "atr_ent" not in df.columns:
        return df[mfe].median() - df[mae].median()
    atr = df["atr_ent"].where(df["atr_ent"] > 0)
    return (df[mfe] / atr).median() - (df[mae] / atr).median()


# Sensores que expressam DIRECAO (-1/0/+1). Para estes, separar pelo valor
# absoluto mistura compra e venda: MFE/MAE ja' sao relativos a' direcao do
# sinal, entao "st_local=+1" agrupa altas com baixas e o resultado nao quer
# dizer nada. O sensor com significado e' a CONCORDANCIA com `dir`.
# (st_acordo e est_acordo NAO entram aqui: medem acordo entre os proprios
# componentes do sensor, nao com o sinal - est_acordo bate com dir em 20,4%.)
DIRECIONAIS = ["st_local", "st_regime", "est_micro", "est_macro",
               "sp_trend", "sp_trend_tf"]


def divide(s, dirs=None):
    """Separa em (mascara_favoravel, rotulo). Direcional -> concorda com dir;
    booleano/categorico -> por valor; continuo -> pela mediana."""
    if dirs is not None and s.name in DIRECIONAIS:
        m = (s == dirs)
        return m, "%s CONCORDA com a direcao do sinal" % s.name
    nu = s.nunique(dropna=True)
    if nu < 2:
        return None
    if nu == 2:
        vs = sorted(s.dropna().unique())
        return (s == vs[1]), "%s=%s vs %s" % (s.name, vs[1], vs[0])
    if nu <= 5 and s.dtype.kind in "iu":
        vs = sorted(s.dropna().unique())
        return (s == vs[-1]), "%s=%s vs resto" % (s.name, vs[-1])
    med = s.median()
    return (s > med), "%s > mediana(%.4g)" % (s.name, med)


def main():
    caminho = acha_csv(sys.argv[1] if len(sys.argv) > 1 else None)
    df = pd.read_csv(caminho, sep=";", encoding="cp1252", on_bad_lines="skip")
    mes = pd.to_datetime(df["time_sig"], errors="coerce",
                         format="mixed").dt.to_period("M")
    meses = sorted(m for m in mes.dropna().unique())

    print("arquivo : %s" % os.path.basename(caminho))
    print("sinais  : %d em %d meses (%s a %s)"
          % (len(df), len(meses), meses[0], meses[-1]))
    print("custo de referencia: %.0f pts | grupo minimo: %d sinais"
          % (CUSTO_PTS, MIN_GRUPO))
    print("")
    global CUSTO_ATR
    atr_med = df["atr_ent"].median()
    CUSTO_ATR = CUSTO_PTS / atr_med
    print("ATR mediano na entrada: %.0f pts -> custo de %.0f pts = %.3f ATR"
          % (atr_med, CUSTO_PTS, CUSTO_ATR))
    print("")
    print("Base de comparacao - assimetria de TODOS os sinais (em ATR):")
    for h in HORIZONTES:
        print("  %2d barras: %+7.3f ATR   (%+8.0f pts)"
              % (h, assimetria(df, h), assimetria(df, h, em_atr=False)))

    achados, quase = [], []

    for nome, cols in FAMILIAS:
        print("")
        print("=" * 74)
        print("FAMILIA: %s" % nome)
        print("=" * 74)
        for c in cols:
            if c not in df.columns:
                print("  %-14s (coluna ausente)" % c)
                continue
            d = divide(df[c], df["dir"])
            if d is None:
                print("  %-14s constante - nao separa" % c)
                continue
            masc, rotulo = d
            a, b = df[masc], df[~masc]
            if len(a) < MIN_GRUPO or len(b) < MIN_GRUPO:
                print("  %-14s grupos pequenos (%d / %d) - nao avalio"
                      % (c, len(a), len(b)))
                continue

            difs = []
            print("  %s" % rotulo)
            print("     n = %d favoravel / %d resto" % (len(a), len(b)))
            for h in HORIZONTES:
                aa, bb = assimetria(a, h), assimetria(b, h)
                difs.append(aa - bb)
                print("     %2d barras: %+7.3f vs %+7.3f   dif %+7.3f ATR"
                      % (h, aa, bb, aa - bb))

            mesmo_sinal = all(x > 0 for x in difs) or all(x < 0 for x in difs)
            acima_custo = abs(difs[1]) > CUSTO_ATR   # 15 barras e' o horizonte de referencia

            # (c) estabilidade mensal: em quantos meses o sinal se repete?
            mesmo = 0
            for m in meses:
                dm = df[mes == m]
                am, bm = dm[masc.reindex(dm.index, fill_value=False)], \
                         dm[~masc.reindex(dm.index, fill_value=False)]
                if len(am) < 5 or len(bm) < 5:
                    continue
                d15 = assimetria(am, 15) - assimetria(bm, 15)
                if d15 is not None and (d15 > 0) == (difs[1] > 0):
                    mesmo += 1
            print("     mesmo sinal em %d de %d meses | 3 horizontes: %s | > custo: %s"
                  % (mesmo, len(meses), "sim" if mesmo_sinal else "NAO",
                     "sim" if acima_custo else "nao"))

            reg = (nome, rotulo, difs[1], mesmo, len(meses))
            if mesmo_sinal and acima_custo and mesmo >= 5:
                achados.append(reg)
            elif acima_custo and (mesmo_sinal or mesmo >= 5):
                quase.append(reg)

    print("")
    print("=" * 74)
    print("VEREDITO CONTRA O PRE-REGISTRO")
    print("=" * 74)
    if achados:
        print("Passaram nas TRES condicoes (a+b+c):")
        for f, r, d, m, tot in achados:
            print("  [%s] %s | dif15 %+.3f ATR | %d/%d meses" % (f, r, d, m, tot))
    else:
        print("Nenhum sensor passou nas tres condicoes.")
    if quase:
        print("")
        print("Passaram em DUAS - hipotese para pre-registrar, nao achado:")
        for f, r, d, m, tot in quase:
            print("  [%s] %s | dif15 %+.3f ATR | %d/%d meses" % (f, r, d, m, tot))
    print("")
    print("Assimetria e' condicao NECESSARIA, nao suficiente. Nada aqui promove")
    print("hipotese: promocao exige OOS, estabilidade e teste do descartado.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
