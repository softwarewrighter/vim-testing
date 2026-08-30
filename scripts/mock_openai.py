#!/usr/bin/env python3
"""
testing/scripts/mock_openai.py

A dependency-free mock of the OpenAI-compatible surface vimgem talks to:

    GET  /v1/models
    POST /v1/chat/completions

Why this exists
---------------
Live local models are the thing you ultimately want to test against, but
they are slow (seconds per turn), non-deterministic, and cannot produce
the failure modes that actually break the plugin: HTTP 500s, malformed
JSON, an `error` object in a 200 body, or finish_reason == "length"
(vimgem's only truncation signal on this protocol -- see
autoload/ai/openai.vim ExtractResult).

So: the mock owns correctness and error-path coverage and runs offline in
milliseconds; the live backends own compatibility coverage. See
docs/test-plan.md for how the two tiers divide the work.

Scripted behaviour
------------------
The response is chosen by scanning the last user message for a directive:

    !echo <text>        reply with <text> verbatim
    !truncate           reply with finish_reason "length"
    !status <code>      reply with that HTTP status and an error body
    !apierror <msg>     HTTP 200 carrying {"error": {"message": msg}}
    !badjson            HTTP 200 carrying text that is not JSON
    !slow <seconds>     sleep, then reply OK (for timeout tests)
    !count              reply with the number of messages received,
                        as "turns=<n>" -- proves chat history is being
                        resent, which is the core :AIChatSend contract
    !dump               reply with the whole received message list as
                        role:text pairs, one per line
    !reasoning          a thinking model's shape: reasoning_content full,
                        content present but EMPTY
    !reasoning-only     a thinking model that spent every token thinking:
                        reasoning_content full, no content key at all

Anything else echoes back "mock: <the prompt>".

Every request is appended as one JSON line to the file given by
--log, so tests can assert on exactly what vimgem put on the wire
(model field present or omitted, roles, ordering, headers).

Usage
-----
    ./mock_openai.py --port 9099 --log /tmp/requests.jsonl
    ./mock_openai.py --port 9099 --models a,b,c
"""

import argparse
import json
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ARGS = None


def parse_directive(text):
    """Return (kind, arg) for the first recognised ! directive, else (None, None)."""
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("!"):
            continue
        head, _, rest = line[1:].partition(" ")
        if head in (
            "echo", "truncate", "status", "apierror", "badjson", "slow",
            "count", "dump", "reasoning", "reasoning-only",
        ):
            return head, rest.strip()
    return None, None


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    # Keep the test output readable; the request log file is the record.
    def log_message(self, fmt, *a):
        if ARGS.verbose:
            sys.stderr.write("mock: " + (fmt % a) + "\n")

    def _send(self, code, body, ctype="application/json"):
        raw = body.encode() if isinstance(body, str) else body
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def _json(self, code, obj):
        self._send(code, json.dumps(obj))

    def _record(self, entry):
        if not ARGS.log:
            return
        with open(ARGS.log, "a") as fh:
            fh.write(json.dumps(entry) + "\n")

    def do_GET(self):
        if self.path.rstrip("/") != "/v1/models":
            self._json(404, {"error": {"message": f"no route {self.path}"}})
            return
        self._record({"path": self.path, "method": "GET"})
        self._json(200, {
            "object": "list",
            "data": [{"id": m, "object": "model", "owned_by": "mock"}
                     for m in ARGS.models],
        })

    def do_POST(self):
        if self.path.rstrip("/") != "/v1/chat/completions":
            self._json(404, {"error": {"message": f"no route {self.path}"}})
            return

        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length).decode() if length else ""
        try:
            payload = json.loads(raw)
        except ValueError:
            self._json(400, {"error": {"message": "mock could not parse request"}})
            return

        messages = payload.get("messages", [])
        self._record({
            "path": self.path,
            "method": "POST",
            # Whether "model" is present at all is a real contract: vimgem
            # omits it when g:openai_model is empty. Distinguish absent
            # from empty rather than collapsing both to "".
            "model_present": "model" in payload,
            "model": payload.get("model"),
            "n_messages": len(messages),
            "messages": messages,
            "authorization": self.headers.get("Authorization"),
        })

        last_user = ""
        for m in reversed(messages):
            if m.get("role") == "user":
                last_user = m.get("content", "")
                break

        kind, arg = parse_directive(last_user)

        if kind == "status":
            code = int(arg or 500)
            self._json(code, {"error": {"message": f"mock forced HTTP {code}"}})
            return
        if kind == "apierror":
            self._json(200, {"error": {"message": arg or "mock api error"}})
            return
        if kind == "badjson":
            self._send(200, "this is definitely not json {{{", ctype="text/plain")
            return
        if kind == "slow":
            time.sleep(float(arg or 5))
            content, finish = "OK", "stop"
        elif kind == "truncate":
            content, finish = "this reply was cut off mid-", "length"
        elif kind == "echo":
            content, finish = arg, "stop"
        elif kind == "count":
            content, finish = f"turns={len(messages)}", "stop"
        elif kind == "dump":
            content = "\n".join(
                f"{m.get('role')}:{m.get('content', '')}" for m in messages
            )
            finish = "stop"
        else:
            content, finish = f"mock: {last_user}", "stop"

        # Reasoning models (llama.cpp with a thinking model, and others)
        # return their chain of thought in a separate reasoning_content
        # field. Two shapes are worth reproducing: content present but
        # empty, and content missing entirely. vimgem reads only
        # message.content, so these are where it goes wrong -- see
        # Issue 5 in docs/test-plan.md.
        message = {"role": "assistant"}
        if kind == "reasoning":
            message["reasoning_content"] = (
                "Let me think. The user asked a question. I will consider "
                "several approaches before answering."
            )
            message["content"] = ""
            finish = "length"
        elif kind == "reasoning-only":
            message["reasoning_content"] = (
                "Thinking at length and never reaching a final answer."
            )
            finish = "length"
        else:
            message["content"] = content

        self._json(200, {
            "id": "chatcmpl-mock",
            "object": "chat.completion",
            "created": int(time.time()),
            "model": payload.get("model", "mock-model"),
            "choices": [{
                "index": 0,
                "message": message,
                "finish_reason": finish,
            }],
            "usage": {"prompt_tokens": 0, "completion_tokens": 0, "total_tokens": 0},
        })


def main():
    global ARGS
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--port", type=int, default=9099)
    p.add_argument("--host", default="127.0.0.1")
    p.add_argument("--log", help="append one JSON line per request to this file")
    p.add_argument("--models", default="mock-small,mock-large",
                   help="comma-separated model ids for GET /v1/models")
    p.add_argument("--verbose", action="store_true")
    ARGS = p.parse_args()
    ARGS.models = [m for m in ARGS.models.split(",") if m]

    srv = ThreadingHTTPServer((ARGS.host, ARGS.port), Handler)
    # Print the ready line on stdout so the shell runner can block until
    # the port is actually accepting, instead of sleeping and hoping.
    print(f"mock_openai listening on http://{ARGS.host}:{ARGS.port}", flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
