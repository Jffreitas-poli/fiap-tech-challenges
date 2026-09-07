package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestGetDeterministicBucket(t *testing.T) {
	// deterministico: mesma entrada -> mesmo bucket
	a := getDeterministicBucket("user-42:checkout")
	b := getDeterministicBucket("user-42:checkout")
	if a != b {
		t.Fatalf("bucket nao deterministico: %d != %d", a, b)
	}
	// sempre no intervalo [0,99]
	for _, in := range []string{"", "x", "user-1flag", "AAAA", "z9"} {
		if got := getDeterministicBucket(in); got < 0 || got > 99 {
			t.Errorf("bucket fora de [0,99] para %q: %d", in, got)
		}
	}
}

func TestRunEvaluationLogic(t *testing.T) {
	app := &App{}
	enabled := &Flag{Name: "f", IsEnabled: true}

	tests := []struct {
		name string
		info *CombinedFlagInfo
		want bool
	}{
		{"flag nil", &CombinedFlagInfo{}, false},
		{"flag desligada", &CombinedFlagInfo{Flag: &Flag{IsEnabled: false}}, false},
		{"flag ligada, sem regra", &CombinedFlagInfo{Flag: enabled}, true},
		{"flag ligada, regra desligada", &CombinedFlagInfo{Flag: enabled, Rule: &TargetingRule{IsEnabled: false}}, true},
		{"rollout 100%", &CombinedFlagInfo{Flag: enabled, Rule: &TargetingRule{IsEnabled: true, Rules: Rule{Type: "PERCENTAGE", Value: float64(100)}}}, true},
		{"rollout 0%", &CombinedFlagInfo{Flag: enabled, Rule: &TargetingRule{IsEnabled: true, Rules: Rule{Type: "PERCENTAGE", Value: float64(0)}}}, false},
		{"valor de regra invalido", &CombinedFlagInfo{Flag: enabled, Rule: &TargetingRule{IsEnabled: true, Rules: Rule{Type: "PERCENTAGE", Value: "nan"}}}, false},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			if got := app.runEvaluationLogic(tc.info, "user-1"); got != tc.want {
				t.Errorf("runEvaluationLogic = %v, quer %v", got, tc.want)
			}
		})
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
