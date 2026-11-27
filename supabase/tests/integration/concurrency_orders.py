"""Concurrencia real de pedidos contra un proyecto Supabase de DESARROLLO.

Cada solicitud usa su propia conexión HTTPS a PostgREST (rol anónimo, clave publicable),
así que las transacciones compiten de verdad en la base. Los pedidos creados se cancelan
al terminar, por lo que se puede repetir.

    python supabase/tests/integration/concurrency_orders.py            # usa app/env/dev.json

Requiere los datos ficticios "Fixture Concurrencia 1/2" (ver README, sección Pruebas).
"""
import json
import os
import random
import sys
import threading
import urllib.error
import urllib.request

PRODUCTION_REF = "lvejfwatzdqpzftjraut"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

cfg = json.load(open(os.path.join(ROOT, "app", "env", "dev.json"), encoding="utf-8"))
URL, KEY = cfg["SUPABASE_URL"], cfg["SUPABASE_ANON_KEY"]
if PRODUCTION_REF in URL or cfg.get("APP_ENV") != "dev":
    sys.exit("Abortado: esta prueba solo se ejecuta contra un proyecto de desarrollo.")


def rpc(name, body):
    req = urllib.request.Request(
        f"{URL}/rest/v1/rpc/{name}", data=json.dumps(body).encode(), method="POST",
        headers={"apikey": KEY, "Authorization": f"Bearer {KEY}", "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as res:
            return True, json.load(res)
    except urllib.error.HTTPError as err:
        return False, json.load(err).get("message", str(err.code))


def parallel(bodies):
    """Lanza todas las solicitudes a la vez (barrera) y devuelve los resultados."""
    gate = threading.Barrier(len(bodies))
    out = [None] * len(bodies)

    def run(i):
        gate.wait()
        out[i] = rpc("create_order", bodies[i])

    threads = [threading.Thread(target=run, args=(i,)) for i in range(len(bodies))]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    return out


def order(event, phone, i):
    return {"p_event_id": event["id"], "p_buyer_name": f"Concurrente {i}", "p_buyer_ci": f"CC{i:06d}",
            "p_buyer_phone": phone, "p_buyer_email": None,
            "p_lines": [{"type_id": event["types"][order.kind], "qty": 1}]}


ok, catalog = rpc("public_events", {})
assert ok, catalog
events = sorted((e for e in catalog if e["name"].startswith("Fixture Concurrencia")), key=lambda e: e["name"])
if len(events) != 2:
    sys.exit("Faltan los datos ficticios 'Fixture Concurrencia 1/2' en el proyecto de desarrollo.")
for e in events:
    e["types"] = {t["name"]: t["id"] for t in e["types"]}

created, failures = [], []


def check(label, condition, detail):
    print(("PASS " if condition else "FAIL ") + label + f"  [{detail}]")
    if not condition:
        failures.append(label)


def summary(results):
    good = [r for ok_, r in results if ok_]
    errors = {}
    for ok_, r in results:
        if not ok_:
            errors[r] = errors.get(r, 0) + 1
    created.extend(good)
    return good, errors


try:
    # 1) Un mismo teléfono, formatos distintos, dos locales: solo 3 pedidos activos.
    order.kind = "General"
    n = f"7{random.randint(0, 9999999):07d}"
    formats = [n, f"+591 {n}", f"00591{n}", f"{n[:4]} {n[4:]}", f"(591) {n[:1]}-{n[1:]}", f"0{n}"]
    results = parallel([order(events[i % 2], formats[i % len(formats)], i) for i in range(18)])
    good, errors = summary(results)
    check("18 solicitudes simultáneas del mismo teléfono -> exactamente 3", len(good) == 3
          and errors == {"too_many_open_orders": 15}, f"aceptadas={len(good)} rechazos={errors}")

    # 2) Cancelar libera el límite.
    done = good[0]
    rpc("cancel_order", {"p_order_id": done["order_id"], "p_token": done["token"]})
    results = parallel([order(events[0], n, 100 + i) for i in range(4)])
    good2, errors2 = summary(results)
    check("al cancelar uno se admite exactamente uno más", len(good2) == 1, f"aceptadas={len(good2)} rechazos={errors2}")
    for o in created:
        rpc("cancel_order", {"p_order_id": o["order_id"], "p_token": o["token"]})

    # 3) Categoría con 5 cupos, 25 compradores a la vez: sin sobreventa.
    order.kind = "Cinco"
    results = parallel([order(events[0], f"6{random.randint(0, 9999999):07d}", 200 + i) for i in range(25)])
    good3, errors3 = summary(results)
    check("25 compradores por 5 cupos -> exactamente 5", len(good3) == 5 and errors3 == {"sold_out": 20},
          f"aceptadas={len(good3)} rechazos={errors3}")
    ok, catalog = rpc("public_events", {})
    left = [t["available"] for e in catalog if e["id"] == events[0]["id"] for t in e["types"] if t["name"] == "Cinco"]
    check("el catálogo reporta 0 disponibles", left == [0], f"disponibles={left}")

    # 4) El importe lo calcula el servidor: el cliente no puede enviarlo.
    ok, res = rpc("create_order", {**order(events[0], "60000000", 999), "p_total": 0.01})
    check("no existe parámetro de importe manipulable", not ok, str(res)[:80])
finally:
    for o in created:
        rpc("cancel_order", {"p_order_id": o["order_id"], "p_token": o["token"]})

print(f"\n{'OK' if not failures else 'FALLÓ'}: {len(failures)} fallo(s)")
sys.exit(1 if failures else 0)
