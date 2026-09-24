#!/usr/bin/env python3
"""Test ferdek --dap: rozmowa jak z VS Code - punkt zatrzymania, stos, zmienne, krok, wyjście programu."""
import json
import os
import subprocess
import sys

FERDEK = sys.argv[1] if len(sys.argv) > 1 else "_build/default/src/ferdek.exe"
PROGRAM = os.path.abspath("tests/debug/program.ferdek")

proc = subprocess.Popen([FERDEK, "--dap"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
seq = 0
events = []
failures = 0


def read():
    length = None
    while True:
        line = proc.stdout.readline().strip()
        if not line:
            break
        k, v = line.split(b":", 1)
        if k.lower() == b"content-length":
            length = int(v)
    return json.loads(proc.stdout.read(length))


def request(command, arguments=None):
    global seq
    seq += 1
    body = json.dumps({"seq": seq, "type": "request", "command": command, "arguments": arguments or {}}).encode()
    proc.stdin.write(b"Content-Length: %d\r\n\r\n" % len(body) + body)
    proc.stdin.flush()
    while True:
        m = read()
        if m["type"] == "response" and m["request_seq"] == seq:
            return m
        events.append(m)


def wait_event(name):
    while True:
        for e in events:
            if e["event"] == name:
                events.remove(e)
                return e
        events.append(read())


def check(what, got, want):
    global failures
    if got != want:
        failures += 1
        print(f"FAIL {what}: {got!r} != {want!r}")


def top():
    frames = request("stackTrace", {"threadId": 1})["body"]["stackFrames"]
    return [(f["name"], f["line"]) for f in frames]


def variables(ref):
    return {v["name"]: v["value"] for v in request("variables", {"variablesReference": ref})["body"]["variables"]}


check("initialize", request("initialize", {"adapterID": "ferdek"})["success"], True)
wait_event("initialized")
check("launch", request("launch", {"program": PROGRAM})["success"], True)
request("setBreakpoints", {"source": {"path": PROGRAM}, "breakpoints": [{"line": 12}]})
request("configurationDone")

check("zatrzymanie", wait_event("stopped")["body"]["reason"], "breakpoint")
check("stos na punkcie", top(), [("program", 12)])
check("globalne", variables(2), {"i": "1", "suma": "0"})
check("wyrażenie", request("evaluate", {"expression": "suma BABKA DAWAJ RENTĘ 100", "frameId": 0})["body"]["result"], "100")

request("stepIn", {"threadId": 1})
wait_event("stopped")
check("stos w funkcji", top(), [("podwoj", 5), ("program", 12)])
check("lokalne", variables(1), {"x": "1"})

request("setBreakpoints", {"source": {"path": PROGRAM}, "breakpoints": []})
request("continue", {"threadId": 1})
check("kod wyjścia", wait_event("exited")["body"]["exitCode"], 0)
output = "".join(e["body"]["output"] for e in events if e["event"] == "output")
check("wyjście programu", output, "Suma: 12\n")
request("disconnect")
proc.wait(timeout=5)

# CO TAM U PANA SŁYCHAĆ: wejście z konfiguracji ("input"); bez niego - czytelny błąd, a nie protokół
WEJSCIE = os.path.abspath("tests/debug/wejscie.ferdek")
for launch, want in [({"input": "Waldek\n41\n"}, "Cześć Waldek\n42\n"), ({}, "w debuggerze podaj wejście")]:
    proc = subprocess.Popen([FERDEK, "--dap"], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    events = []
    request("initialize", {"adapterID": "ferdek"})
    wait_event("initialized")
    request("launch", dict({"program": WEJSCIE}, **launch))
    request("configurationDone")
    wait_event("exited")
    output = "".join(e["body"]["output"] for e in events if e["event"] == "output")
    check(f"wejście {launch}", want in output, True)
    request("disconnect")
    proc.wait(timeout=5)

if failures:
    sys.exit(1)
print("--- dap: OK")
