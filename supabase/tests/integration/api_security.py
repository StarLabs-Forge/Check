"""Comprobaciones de seguridad por la API pública (rol anónimo) contra DESARROLLO.

    python supabase/tests/integration/api_security.py          # usa app/env/dev.json
"""
import json
import os
import sys
import urllib.error
import urllib.request

PRODUCTION_REF = "lvejfwatzdqpzftjraut"
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
cfg = json.load(open(os.path.join(ROOT, "app", "env", "dev.json"), encoding="utf-8"))
URL, KEY = cfg["SUPABASE_URL"], cfg["SUPABASE_ANON_KEY"]
if PRODUCTION_REF in URL or cfg.get("APP_ENV") != "dev":
    sys.exit("Abortado: esta prueba solo se ejecuta contra un proyecto de desarrollo.")

ZERO = "00000000-0000-4000-8000-000000000000"
failures = []


def call(method, path, body=None):
    req = urllib.request.Request(URL + path, method=method,
                                 data=None if body is None else json.dumps(body).encode(),
                                 headers={"apikey": KEY, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as res:
            raw = res.read()
            return res.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as err:
        raw = err.read()
        return err.code, json.loads(raw) if raw else None


def check(label, ok, detail):
    print(("PASS " if ok else "FAIL ") + label + f"  [{detail}]")
    if not ok:
        failures.append(label)


TABLES = ["profiles", "venues", "events", "orders", "order_lines", "order_secrets", "tickets", "ticket_types",
          "audit_log", "platform_log", "platform_settings", "event_status_log", "ticket_type_log",
          "venue_trials", "venue_subscriptions", "venue_commercial_log", "trial_notifications", "mfa_resets",
          "staff_accounts", "events_with_stats"]
readable = [t for t in TABLES if call("GET", f"/rest/v1/{t}?select=*&limit=1")[0] < 400]
check(f"anónimo no lee ninguna de {len(TABLES)} tablas/vistas", not readable, readable or "todas rechazadas")

status, _ = call("POST", "/rest/v1/ticket_types", {"event_id": ZERO, "name": "x", "price": 0, "capacity": 1})
check("anónimo no escribe categorías", status >= 400, status)
status, _ = call("PATCH", f"/rest/v1/events?id=eq.{ZERO}", {"status": "active"})
check("anónimo no cambia estados", status >= 400, status)

RPCS = {
    "set_event_status": {"p_event_id": ZERO, "p_status": "active"},
    "start_trial": {}, "trial_status": {},
    "decide_order": {"p_order_id": ZERO, "p_approve": True},
    "create_ticket": {"p_event_id": ZERO, "p_guest_name": "x", "p_ticket_type_id": ZERO},
    "validate_qr": {"p_token": "x", "p_event_id": ZERO},
    "superadmin_users": {}, "superadmin_commercial_overview": {},
    "superadmin_assign_plan": {"p_owner_id": ZERO, "p_plan": "pro", "p_note": "xxxx"},
    "superadmin_authorize_mfa_reset": {"p_user_id": ZERO, "p_reason": "xxxxxxxxxxxx"},
    "ticket_type_stats": {"p_event_id": ZERO}, "session_mfa_status": {},
    "enqueue_trial_notifications": {},
}
allowed = [n for n, body in RPCS.items() if call("POST", f"/rest/v1/rpc/{n}", body)[0] < 400]
check(f"anónimo no ejecuta {len(RPCS)} funciones privadas", not allowed, allowed or "todas rechazadas")

status, body = call("POST", "/rest/v1/rpc/get_order", {"p_order_id": ZERO, "p_token": "adivinado"})
check("consultar un pedido exige su token", status >= 400, (body or {}).get("message"))

status, catalog = call("POST", "/rest/v1/rpc/public_events", {})
leaked = [k for e in catalog or [] for k in e if k in ("owner_id", "bank_account", "bank_beneficiary")]
check("el catálogo público no expone dueño ni datos bancarios", status == 200 and not leaked, leaked or "ok")
for fn in ("create-venue", "create-staff", "mfa-reset"):
    status, _ = call("POST", f"/functions/v1/{fn}", {})
    check(f"Edge Function {fn} rechaza llamadas sin sesión", status in (401, 403), status)

print(f"\n{'OK' if not failures else 'FALLÓ'}: {len(failures)} fallo(s)")
sys.exit(1 if failures else 0)
