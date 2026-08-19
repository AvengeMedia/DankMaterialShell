package keybinds

import (
	"slices"
	"testing"
)

type mockProvider struct {
	name string
	err  error
}

func (m *mockProvider) Name() string {
	return m.name
}

func (m *mockProvider) GetCheatSheet() (*CheatSheet, error) {
	if m.err != nil {
		return nil, m.err
	}
	return &CheatSheet{
		Title:    "Test",
		Provider: m.name,
		Binds:    make(map[string][]Keybind),
	}, nil
}

func TestNewRegistry(t *testing.T) {
	r := NewRegistry()
	if r == nil {
		t.Fatal("NewRegistry returned nil")
	}

	if r.providers == nil {
		t.Error("providers map is nil")
	}
}

func TestRegisterProvider(t *testing.T) {
	tests := []struct {
		name        string
		provider    Provider
		expectError bool
		errorMsg    string
	}{
		{
			name:        "valid provider",
			provider:    &mockProvider{name: "test"},
			expectError: false,
		},
		{
			name:        "nil provider",
			provider:    nil,
			expectError: true,
			errorMsg:    "cannot register nil provider",
		},
		{
			name:        "empty name",
			provider:    &mockProvider{name: ""},
			expectError: true,
			errorMsg:    "provider name cannot be empty",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r := NewRegistry()
			err := r.Register(tt.provider)

			if tt.expectError {
				if err == nil {
					t.Error("expected error, got nil")
				}
				return
			}

			if err != nil {
				t.Errorf("unexpected error: %v", err)
			}
		})
	}
}

func TestRegisterDuplicate(t *testing.T) {
	r := NewRegistry()
	p := &mockProvider{name: "test"}

	if err := r.Register(p); err != nil {
		t.Fatalf("first registration failed: %v", err)
	}

	err := r.Register(p)
	if err == nil {
		t.Error("expected error when registering duplicate, got nil")
	}
}

func TestGetProvider(t *testing.T) {
	r := NewRegistry()
	p := &mockProvider{name: "test"}

	if err := r.Register(p); err != nil {
		t.Fatalf("registration failed: %v", err)
	}

	retrieved, err := r.Get("test")
	if err != nil {
		t.Fatalf("Get failed: %v", err)
	}

	if retrieved.Name() != "test" {
		t.Errorf("Got provider name %q, want %q", retrieved.Name(), "test")
	}
}

func TestGetNonexistent(t *testing.T) {
	r := NewRegistry()

	_, err := r.Get("nonexistent")
	if err == nil {
		t.Error("expected error for nonexistent provider, got nil")
	}
}

func TestListProviders(t *testing.T) {
	r := NewRegistry()

	p1 := &mockProvider{name: "test1"}
	p2 := &mockProvider{name: "test2"}
	p3 := &mockProvider{name: "test3"}

	r.Register(p1)
	r.Register(p2)
	r.Register(p3)

	list := r.List()

	if len(list) != 3 {
		t.Errorf("expected 3 providers, got %d", len(list))
	}

	found := make(map[string]bool)
	for _, name := range list {
		found[name] = true
	}

	expected := []string{"test1", "test2", "test3"}
	for _, name := range expected {
		if !found[name] {
			t.Errorf("expected provider %q not found in list", name)
		}
	}
}

func TestDefaultRegistry(t *testing.T) {
	p := &mockProvider{name: "default-test"}

	err := Register(p)
	if err != nil {
		t.Fatalf("Register failed: %v", err)
	}

	retrieved, err := Get("default-test")
	if err != nil {
		t.Fatalf("Get failed: %v", err)
	}

	if retrieved.Name() != "default-test" {
		t.Errorf("Got provider name %q, want %q", retrieved.Name(), "default-test")
	}

	list := List()
	found := slices.Contains(list, "default-test")

	if !found {
		t.Error("provider not found in default registry list")
	}
}
