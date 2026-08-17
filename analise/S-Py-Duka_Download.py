# -*- coding: utf-8 -*-
"""
S-Py-Duka_Download.py — baixa tick data da Dukascopy hora a hora, em cascata.

PASTA:    C:\\dev\\SBurn\\analise\\
REQUER:   Python 3.9+ (so' biblioteca padrao; nao precisa de pandas nem Node)
USO:
    python S-Py-Duka_Download.py --symbol XAUUSD --de 2022-01 --ate 2026-08
    python S-Py-Duka_Download.py --symbol XAUUSD --de 2022-01 --ate 2026-08 --relatorio

O QUE FAZ
  Percorre mes a mes, dia a dia, hora a hora. Cada hora e' um arquivo .bi5 na
  Dukascopy. Guarda o arquivo BRUTO (comprimido) espelhado em disco e registra o
  resultado de cada hora num manifesto. Interrompeu? Rode de novo: ele retoma de
  onde parou, sem rebaixar nada.

POR QUE HORA A HORA E NAO "MES INTEIRO"
  Baixar em cascata nao evita corrupcao por si so' — o que evita e':
    (a) validar CADA arquivo no momento em que chega (descomprime? tamanho e'
        multiplo de 20 bytes? precos dentro de faixa plausivel?),
    (b) registrar no manifesto o que deu certo, o que nao tinha dado (404 em fim
        de semana e' NORMAL) e o que falhou de verdade,
    (c) poder retomar sem duvida sobre o que ja' existe.
  O risco real nao e' arquivo corrompido — e' MES INCOMPLETO QUE PARECE COMPLETO.
  O manifesto e o relatorio de lacunas existem para isso.
  A cascata serve tambem para nao levar bloqueio por excesso de requisicoes.

FORMATO .bi5 (documentado aqui porque ninguem lembra depois)
  URL:  https://datafeed.dukascopy.com/datafeed/{SIMBOLO}/{ANO}/{MES}/{DIA}/{HORA}h_ticks.bi5
        ATENCAO: o MES na URL e' ZERO-INDEXADO (00 = janeiro, 11 = dezembro).
        Em disco guardamos 1-indexado, que e' legivel por humanos.
  Conteudo: LZMA cru. Descomprimido = N registros de 20 bytes, big-endian:
        uint32  ms desde o inicio da hora
        uint32  ask (inteiro, precisa de escala)
        uint32  bid (inteiro, precisa de escala)
        float32 volume ask
        float32 volume bid
  Horario: UTC. O servidor da Exness e' GMT+2/+3 — o deslocamento e' aplicado na
  etapa de IMPORTACAO, nao aqui. Este arquivo e' a fonte bruta, sem opiniao.
  Escala: descoberta empiricamente na primeira hora valida (ver --faixa).

SAIDA
  <saida>/<SIMBOLO>/<ANO>/<MES>/<DIA>/<HORA>h_ticks.bi5   (bruto, como veio)
  <saida>/<SIMBOLO>/_manifesto.jsonl                      (uma linha por hora)
"""

import argparse
import json
import lzma
import os
import struct
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone

BASE = "https://datafeed.dukascopy.com/datafeed"
REG = 20                      # bytes por tick
UA = "Mozilla/5.0 (SBurn data fetch)"

# faixa plausivel de preco por simbolo, para validar a escala.
# se o valor decodificado cair fora, a escala esta errada e o script AVISA.
FAIXA = {
    "XAUUSD": (500.0, 20000.0),
    "XAGUSD": (5.0, 200.0),
    "EURUSD": (0.5, 2.0),
    "USDJPY": (50.0, 300.0),
}
ESCALA_PADRAO = {"XAUUSD": 1000.0, "XAGUSD": 1000.0, "USDJPY": 1000.0}


def url_hora(simbolo, dt):
    """Monta a URL. O mes vai ZERO-INDEXADO — este e' o erro classico."""
    return (f"{BASE}/{simbolo}/{dt.year:04d}/{dt.month - 1:02d}/"
            f"{dt.day:02d}/{dt.hour:02d}h_ticks.bi5")


def caminho_local(saida, simbolo, dt):
    """Em disco usamos mes 1-indexado (legivel). So' a URL usa 0-indexado."""
    return os.path.join(saida, simbolo, f"{dt.year:04d}", f"{dt.month:02d}",
                        f"{dt.day:02d}", f"{dt.hour:02d}h_ticks.bi5")


def decodifica(bruto, escala):
    """Descomprime e decodifica. Devolve (n_ticks, primeiro_bid, ultimo_bid).
    Levanta ValueError se o conteudo nao fizer sentido."""
    if not bruto:
        return 0, None, None
    dados = lzma.decompress(bruto)
    if len(dados) % REG != 0:
        raise ValueError(f"tamanho {len(dados)} nao e' multiplo de {REG}")
    n = len(dados) // REG
    if n == 0:
        return 0, None, None
    _, _, bid0, _, _ = struct.unpack_from(">IIIff", dados, 0)
    _, _, bidN, _, _ = struct.unpack_from(">IIIff", dados, (n - 1) * REG)
    return n, bid0 / escala, bidN / escala


def baixa(url, tentativas, pausa, timeout=30):
    """Devolve (bytes, status). status: 'ok' | 'sem_dados' | 'erro:<motivo>'.
    404 e' NORMAL: fim de semana, feriado, hora sem negocio."""
    ultimo = ""
    for t in range(tentativas):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read(), "ok"
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return b"", "sem_dados"
            ultimo = f"http{e.code}"
            if e.code in (429, 503):          # throttling: espera progressiva
                time.sleep(pausa * (2 ** t) * 5)
                continue
        except Exception as e:                # rede, timeout, DNS
            ultimo = type(e).__name__
        time.sleep(pausa * (2 ** t))
    return None, f"erro:{ultimo}"


def carrega_manifesto(caminho):
    """Le o manifesto e devolve o conjunto de horas ja' resolvidas."""
    feitas = set()
    if not os.path.exists(caminho):
        return feitas
    with open(caminho, "r", encoding="utf-8") as f:
        for linha in f:
            try:
                r = json.loads(linha)
                if r.get("status") in ("ok", "sem_dados"):
                    feitas.add(r["hora"])
            except Exception:
                continue          # linha truncada por interrupcao: ignora
    return feitas


def horas_do_periodo(de, ate):
    """Gera todas as horas UTC entre o inicio de 'de' e o fim de 'ate'."""
    a, m = map(int, de.split("-"))
    b, n = map(int, ate.split("-"))
    ini = datetime(a, m, 1, tzinfo=timezone.utc)
    fim = datetime(b + (1 if n == 12 else 0), 1 if n == 12 else n + 1, 1,
                   tzinfo=timezone.utc)
    atual = ini
    while atual < fim:
        yield atual
        atual += timedelta(hours=1)


def relatorio(saida, simbolo):
    """Resume o manifesto por mes: horas com dados, sem dados e com erro."""
    man = os.path.join(saida, simbolo, "_manifesto.jsonl")
    if not os.path.exists(man):
        print("Sem manifesto ainda.")
        return
    meses = {}
    for linha in open(man, "r", encoding="utf-8"):
        try:
            r = json.loads(linha)
        except Exception:
            continue
        mes = r["hora"][:7]
        d = meses.setdefault(mes, {"ok": 0, "sem_dados": 0, "erro": 0, "ticks": 0})
        st = r.get("status", "")
        if st == "ok":
            d["ok"] += 1
            d["ticks"] += r.get("ticks", 0)
        elif st == "sem_dados":
            d["sem_dados"] += 1
        else:
            d["erro"] += 1
    print(f"{'mes':<9}{'h com dados':>12}{'h vazias':>10}{'ERROS':>8}{'ticks':>14}")
    total_erro = 0
    for mes in sorted(meses):
        d = meses[mes]
        total_erro += d["erro"]
        alerta = "  <-- REBAIXAR" if d["erro"] else ""
        print(f"{mes:<9}{d['ok']:>12}{d['sem_dados']:>10}{d['erro']:>8}"
              f"{d['ticks']:>14,}{alerta}")
    print(f"\ntotal de horas com ERRO: {total_erro}")
    if total_erro:
        print("Rode o script de novo: ele retoma apenas as horas que faltam.")
    else:
        print("Nenhuma lacuna por erro. Horas vazias sao normais (fim de semana/feriado).")


def main():
    p = argparse.ArgumentParser(description="Download de tick data da Dukascopy, em cascata.")
    p.add_argument("--symbol", default="XAUUSD")
    p.add_argument("--de", required=False, default="2022-01", help="AAAA-MM inicial")
    p.add_argument("--ate", required=False, default="2026-08", help="AAAA-MM final (inclusive)")
    p.add_argument("--saida", default="./duka_raw")
    p.add_argument("--pausa", type=float, default=0.25, help="segundos entre requisicoes")
    p.add_argument("--tentativas", type=int, default=5)
    p.add_argument("--escala", type=float, default=None,
                   help="divisor de preco; padrao por simbolo")
    p.add_argument("--relatorio", action="store_true", help="so' resume o manifesto e sai")
    a = p.parse_args()

    simbolo = a.symbol.upper()
    if a.relatorio:
        relatorio(a.saida, simbolo)
        return

    escala = a.escala or ESCALA_PADRAO.get(simbolo, 100000.0)
    faixa = FAIXA.get(simbolo)
    man_path = os.path.join(a.saida, simbolo, "_manifesto.jsonl")
    os.makedirs(os.path.dirname(man_path), exist_ok=True)
    feitas = carrega_manifesto(man_path)

    horas = list(horas_do_periodo(a.de, a.ate))
    print(f"{simbolo} | {a.de} -> {a.ate} | {len(horas):,} horas | "
          f"ja' resolvidas: {len(feitas):,} | escala: {escala:g}")
    print("Ctrl+C a qualquer momento: o progresso esta no manifesto.\n")

    escala_conferida = False
    mes_atual = None
    cnt = {"ok": 0, "sem_dados": 0, "erro": 0, "ticks": 0}

    with open(man_path, "a", encoding="utf-8") as man:
        for dt in horas:
            chave = dt.strftime("%Y-%m-%dT%H")
            if chave in feitas:
                continue

            if dt.strftime("%Y-%m") != mes_atual:
                if mes_atual:
                    print(f"  {mes_atual}: {cnt['ok']} h com dados, "
                          f"{cnt['sem_dados']} vazias, {cnt['erro']} erros, "
                          f"{cnt['ticks']:,} ticks")
                mes_atual = dt.strftime("%Y-%m")
                cnt = {"ok": 0, "sem_dados": 0, "erro": 0, "ticks": 0}
                print(f"[{mes_atual}] baixando...")

            bruto, status = baixa(url_hora(simbolo, dt), a.tentativas, a.pausa)
            reg = {"hora": chave, "status": status, "ticks": 0}

            if status == "ok":
                try:
                    n, b0, bN = decodifica(bruto, escala)
                    if n and faixa and not escala_conferida:
                        if not (faixa[0] <= b0 <= faixa[1]):
                            print(f"\n  !! PRECO FORA DA FAIXA: {b0:.3f} "
                                  f"(esperado {faixa[0]}-{faixa[1]}).")
                            print("     A escala provavelmente esta errada. "
                                  "Use --escala. Abortando para nao gravar lixo.")
                            sys.exit(2)
                        print(f"  escala conferida: primeiro bid = {b0:.3f}")
                        escala_conferida = True
                    caminho = caminho_local(a.saida, simbolo, dt)
                    os.makedirs(os.path.dirname(caminho), exist_ok=True)
                    tmp = caminho + ".parcial"
                    with open(tmp, "wb") as f:      # grava atomico: so' renomeia
                        f.write(bruto)              # depois de escrever inteiro
                    os.replace(tmp, caminho)
                    reg["ticks"] = n
                    cnt["ok"] += 1
                    cnt["ticks"] += n
                except Exception as e:
                    reg["status"] = f"erro:decodificacao:{type(e).__name__}"
                    cnt["erro"] += 1
            elif status == "sem_dados":
                cnt["sem_dados"] += 1
            else:
                cnt["erro"] += 1

            man.write(json.dumps(reg) + "\n")
            man.flush()                              # sobrevive a Ctrl+C
            time.sleep(a.pausa)

    if mes_atual:
        print(f"  {mes_atual}: {cnt['ok']} h com dados, {cnt['sem_dados']} vazias, "
              f"{cnt['erro']} erros, {cnt['ticks']:,} ticks")
    print("\nConcluido. Resumo por mes:\n")
    relatorio(a.saida, simbolo)


if __name__ == "__main__":
    main()
