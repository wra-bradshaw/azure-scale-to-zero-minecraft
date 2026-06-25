package gateadapter

import (
	"reflect"
	"testing"
)

func TestSplitPlayers(t *testing.T) {
	got := splitPlayers(" MrMoose65,OtherPlayer,, Third ")
	want := []string{"MrMoose65", "OtherPlayer", "Third"}

	if !reflect.DeepEqual(got, want) {
		t.Fatalf("splitPlayers() = %#v, want %#v", got, want)
	}
}
