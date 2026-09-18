package utils

import (
	"testing"
)

func TestFilter(t *testing.T) {
	nums := []int{1, 2, 3, 4, 5}
	evens := Filter(nums, func(n int) bool { return n%2 == 0 })
	if len(evens) != 2 || evens[0] != 2 || evens[1] != 4 {
		t.Errorf("expected [2, 4], got %v", evens)
	}
}

func TestFilterEmpty(t *testing.T) {
	result := Filter([]int{1, 2, 3}, func(n int) bool { return n > 10 })
	if len(result) != 0 {
		t.Errorf("expected empty slice, got %v", result)
	}
}

func TestFind(t *testing.T) {
	nums := []int{1, 2, 3, 4, 5}
	val, found := Find(nums, func(n int) bool { return n == 3 })
	if !found || val != 3 {
		t.Errorf("expected 3, got %v (found=%v)", val, found)
	}
}

func TestFindNotFound(t *testing.T) {
	nums := []int{1, 2, 3}
	val, found := Find(nums, func(n int) bool { return n == 99 })
	if found || val != 0 {
		t.Errorf("expected zero value not found, got %v (found=%v)", val, found)
	}
}

func TestMap(t *testing.T) {
	nums := []int{1, 2, 3}
	doubled := Map(nums, func(n int) int { return n * 2 })
	if len(doubled) != 3 || doubled[0] != 2 || doubled[1] != 4 || doubled[2] != 6 {
		t.Errorf("expected [2, 4, 6], got %v", doubled)
	}
}
