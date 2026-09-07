package main

import (
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestGenerateAPIKey(t *testing.T) {
	k1, err := generateAPIKey()
	if err != nil {
		t.Fatalf("erro inesperado: %v", err)
	}
	if !strings.HasPrefix(k1, "tm_key_") {
		t.Errorf("chave sem prefixo esperado: %q", k1)
	}
	// "tm_key_" (7) + 32 bytes em hex (64) = 71
	if len(k1) != 71 {
		t.Errorf("tamanho da chave = %d, quer 71", len(k1))
	}
	if _, err := hex.DecodeString(strings.TrimPrefix(k1, "tm_key_")); err != nil {
		t.Errorf("corpo da chave nao e hex valido: %v", err)
	}

	k2, _ := generateAPIKey()
	if k1 == k2 {
		t.Errorf("generateAPIKey retornou valores iguais em chamadas seguidas")
	}
}

func TestHashAPIKey(t *testing.T) {
	h1 := hashAPIKey("tm_key_abc")
	h2 := hashAPIKey("tm_key_abc")
	if h1 != h2 {
		t.Errorf("hash nao deterministico: %s != %s", h1, h2)
	}
	if len(h1) != 64 {
		t.Errorf("hash SHA-256 hex deveria ter 64 chars, tem %d", len(h1))
	}
	if h1 == hashAPIKey("tm_key_abd") {
		t.Errorf("hashes de entradas diferentes colidiram")
	}
}

func TestHealthHandler(t *testing.T) {
	app := &App{}
	rec := httptest.NewRecorder()
	app.healthHandler(rec, httptest.NewRequest(http.MethodGet, "/health", nil))

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, quer 200", rec.Code)
	}
	var body map[string]string
	if err := json.Unmarshal(rec.Body.Bytes(), &body); err != nil {
		t.Fatalf("resposta nao e JSON: %v", err)
	}
	if body["status"] != "ok" {
		t.Errorf("status = %q, quer \"ok\"", body["status"])
	}
}

func TestMasterKeyAuthMiddleware(t *testing.T) {
	app := &App{MasterKey: "super-secret"}
	next := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) { w.WriteHeader(http.StatusNoContent) })
	h := app.masterKeyAuthMiddleware(next)

	// sem/errada -> 403
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/admin/keys", nil))
	if rec.Code != http.StatusForbidden {
		t.Errorf("sem chave: status = %d, quer 403", rec.Code)
	}

	// correta -> passa
	rec = httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/admin/keys", nil)
	req.Header.Set("Authorization", "Bearer super-secret")
	h.ServeHTTP(rec, req)
	if rec.Code != http.StatusNoContent {
		t.Errorf("chave correta: status = %d, quer 204", rec.Code)
	}
}
