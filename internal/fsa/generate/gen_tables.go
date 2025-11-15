// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

//go:build ignore

// Command gen_tables generates the finite state automaton transition and
// action tables for the fastparse numeric parsers.
//
// It is intended to be invoked via:
//
//   go generate ./...
//
package main

import (
	"bytes"
	"fmt"
	"go/format"
	"os"
	"path/filepath"
)

const (
	maxStates = 32
	alphabet  = 256
)

type state int

const (
	stateStart state = iota
	stateSign
	stateInteger
	stateDecimal
	stateFraction
	stateExponent
	stateExpSign
	stateExpDigits
	stateHexPrefix
	stateHexInteger
	stateHexDecimal
	stateHexFraction
	stateHexExpMarker
	stateHexExpSign
	stateHexExpDigits
	stateInfinity
	stateNaN
	stateOverflow
	stateUnderflow
	stateError
	stateOK
)

type action uint8

const (
	actionNone action = iota
	actionSetSign
	actionDigit
	actionDot
	actionExpMarker
	actionHexPrefix
	actionHexDigit
	actionHexExpMarker
	actionUnderscore
	actionInfinityChar
	actionNaNChar
)

func main() {
	var transitions [maxStates][alphabet]state
	var actions [maxStates][alphabet]action

	buildFloatMachine(&transitions, &actions)

	if err := writeTables("..", transitions, actions); err != nil {
		panic(err)
	}
}

// buildFloatMachine defines a reasonably complete FSA for decimal float
// parsing. It is designed to be compatible with strconv.ParseFloat semantics
// for common cases and will be refined as tests uncover discrepancies.
func buildFloatMachine(t *[maxStates][alphabet]state, a *[maxStates][alphabet]action) {
	// Default: any unspecified transition goes to error.
	for s := 0; s < maxStates; s++ {
		for ch := 0; ch < alphabet; ch++ {
			t[s][ch] = stateError
			a[s][ch] = actionNone
		}
	}

	// Helper to set transitions over ranges.
	setRange := func(s state, from, to int, ns state, act action) {
		for ch := from; ch <= to; ch++ {
			t[s][ch] = ns
			a[s][ch] = act
		}
	}

	// Start: optional sign, digits, or dot.
	setRange(stateStart, '0', '9', stateInteger, actionDigit)
	t[stateStart]['+'] = stateSign
	a[stateStart]['+'] = actionSetSign
	t[stateStart]['-'] = stateSign
	a[stateStart]['-'] = actionSetSign
	t[stateStart]['.'] = stateDecimal
	a[stateStart]['.'] = actionDot

	// Start of "inf" / "nan" / "0x"
	t[stateStart]['i'] = stateInfinity
	t[stateStart]['I'] = stateInfinity
	t[stateStart]['n'] = stateNaN
	t[stateStart]['N'] = stateNaN

	// "0x" hex prefix.
	t[stateStart]['0'] = stateInteger
	a[stateStart]['0'] = actionDigit

	// Sign state mirrors start but without another sign.
	setRange(stateSign, '0', '9', stateInteger, actionDigit)
	t[stateSign]['.'] = stateDecimal
	a[stateSign]['.'] = actionDot
	t[stateSign]['i'] = stateInfinity
	t[stateSign]['I'] = stateInfinity
	t[stateSign]['n'] = stateNaN
	t[stateSign]['N'] = stateNaN

	// Integer digits.
	setRange(stateInteger, '0', '9', stateInteger, actionDigit)
	t[stateInteger]['.'] = stateFraction
	a[stateInteger]['.'] = actionDot
	t[stateInteger]['e'] = stateExponent
	t[stateInteger]['E'] = stateExponent
	a[stateInteger]['e'] = actionExpMarker
	a[stateInteger]['E'] = actionExpMarker
	t[stateInteger]['_'] = stateInteger
	a[stateInteger]['_'] = actionUnderscore

	// Special-case hex prefix: "0x" / "0X" (only from stateInteger when we've seen just '0').
	t[stateInteger]['x'] = stateHexPrefix
	t[stateInteger]['X'] = stateHexPrefix
	a[stateInteger]['x'] = actionHexPrefix
	a[stateInteger]['X'] = actionHexPrefix

	// Leading dot without integer part.
	setRange(stateDecimal, '0', '9', stateFraction, actionDigit)

	// Fractional digits after '.'.
	setRange(stateFraction, '0', '9', stateFraction, actionDigit)
	t[stateFraction]['e'] = stateExponent
	t[stateFraction]['E'] = stateExponent
	a[stateFraction]['e'] = actionExpMarker
	a[stateFraction]['E'] = actionExpMarker
	t[stateFraction]['_'] = stateFraction
	a[stateFraction]['_'] = actionUnderscore

	// Exponent marker; optional sign then digits.
	t[stateExponent]['+'] = stateExpSign
	t[stateExponent]['-'] = stateExpSign
	setRange(stateExponent, '0', '9', stateExpDigits, actionDigit)

	setRange(stateExpSign, '0', '9', stateExpDigits, actionDigit)

	setRange(stateExpDigits, '0', '9', stateExpDigits, actionDigit)
	t[stateExpDigits]['_'] = stateExpDigits
	a[stateExpDigits]['_'] = actionUnderscore

	// Hex prefix after "0x" - need at least one hex digit.
	for ch := '0'; ch <= '9'; ch++ {
		t[stateHexPrefix][ch] = stateHexInteger
		a[stateHexPrefix][ch] = actionHexDigit
	}
	for ch := 'a'; ch <= 'f'; ch++ {
		t[stateHexPrefix][ch] = stateHexInteger
		a[stateHexPrefix][ch] = actionHexDigit
	}
	for ch := 'A'; ch <= 'F'; ch++ {
		t[stateHexPrefix][ch] = stateHexInteger
		a[stateHexPrefix][ch] = actionHexDigit
	}
	t[stateHexPrefix]['.'] = stateHexDecimal
	a[stateHexPrefix]['.'] = actionDot
	t[stateHexPrefix]['_'] = stateHexPrefix
	a[stateHexPrefix]['_'] = actionUnderscore

	// Hex integer digits (before decimal point).
	for ch := '0'; ch <= '9'; ch++ {
		t[stateHexInteger][ch] = stateHexInteger
		a[stateHexInteger][ch] = actionHexDigit
	}
	for ch := 'a'; ch <= 'f'; ch++ {
		t[stateHexInteger][ch] = stateHexInteger
		a[stateHexInteger][ch] = actionHexDigit
	}
	for ch := 'A'; ch <= 'F'; ch++ {
		t[stateHexInteger][ch] = stateHexInteger
		a[stateHexInteger][ch] = actionHexDigit
	}
	t[stateHexInteger]['_'] = stateHexInteger
	a[stateHexInteger]['_'] = actionUnderscore
	t[stateHexInteger]['.'] = stateHexFraction
	a[stateHexInteger]['.'] = actionDot
	t[stateHexInteger]['p'] = stateHexExpMarker
	t[stateHexInteger]['P'] = stateHexExpMarker
	a[stateHexInteger]['p'] = actionHexExpMarker
	a[stateHexInteger]['P'] = actionHexExpMarker

	// Hex decimal point without integer part.
	for ch := '0'; ch <= '9'; ch++ {
		t[stateHexDecimal][ch] = stateHexFraction
		a[stateHexDecimal][ch] = actionHexDigit
	}
	for ch := 'a'; ch <= 'f'; ch++ {
		t[stateHexDecimal][ch] = stateHexFraction
		a[stateHexDecimal][ch] = actionHexDigit
	}
	for ch := 'A'; ch <= 'F'; ch++ {
		t[stateHexDecimal][ch] = stateHexFraction
		a[stateHexDecimal][ch] = actionHexDigit
	}

	// Hex fractional digits.
	for ch := '0'; ch <= '9'; ch++ {
		t[stateHexFraction][ch] = stateHexFraction
		a[stateHexFraction][ch] = actionHexDigit
	}
	for ch := 'a'; ch <= 'f'; ch++ {
		t[stateHexFraction][ch] = stateHexFraction
		a[stateHexFraction][ch] = actionHexDigit
	}
	for ch := 'A'; ch <= 'F'; ch++ {
		t[stateHexFraction][ch] = stateHexFraction
		a[stateHexFraction][ch] = actionHexDigit
	}
	t[stateHexFraction]['_'] = stateHexFraction
	a[stateHexFraction]['_'] = actionUnderscore
	t[stateHexFraction]['p'] = stateHexExpMarker
	t[stateHexFraction]['P'] = stateHexExpMarker
	a[stateHexFraction]['p'] = actionHexExpMarker
	a[stateHexFraction]['P'] = actionHexExpMarker

	// Hex exponent marker (p/P) - requires exponent in decimal.
	t[stateHexExpMarker]['+'] = stateHexExpSign
	t[stateHexExpMarker]['-'] = stateHexExpSign
	setRange(stateHexExpMarker, '0', '9', stateHexExpDigits, actionDigit)

	setRange(stateHexExpSign, '0', '9', stateHexExpDigits, actionDigit)

	setRange(stateHexExpDigits, '0', '9', stateHexExpDigits, actionDigit)
	t[stateHexExpDigits]['_'] = stateHexExpDigits
	a[stateHexExpDigits]['_'] = actionUnderscore

	// Infinity: "inf" or "infinity" (case-insensitive).
	// State machine: i->n->f[->i->n->i->t->y] with all leading to OK
	t[stateInfinity]['n'] = stateInfinity
	t[stateInfinity]['N'] = stateInfinity
	a[stateInfinity]['n'] = actionInfinityChar
	a[stateInfinity]['N'] = actionInfinityChar

	// After "inf", we can end OR continue with "inity"
	t[stateInfinity]['f'] = stateOK
	t[stateInfinity]['F'] = stateOK
	a[stateInfinity]['f'] = actionInfinityChar
	a[stateInfinity]['F'] = actionInfinityChar

	// From stateOK (after "inf"), allow "inity" to also be valid
	t[stateOK]['i'] = stateOK
	t[stateOK]['I'] = stateOK
	t[stateOK]['n'] = stateOK
	t[stateOK]['N'] = stateOK
	t[stateOK]['t'] = stateOK
	t[stateOK]['T'] = stateOK
	t[stateOK]['y'] = stateOK
	t[stateOK]['Y'] = stateOK
	a[stateOK]['i'] = actionInfinityChar
	a[stateOK]['I'] = actionInfinityChar
	a[stateOK]['n'] = actionInfinityChar
	a[stateOK]['N'] = actionInfinityChar
	a[stateOK]['t'] = actionInfinityChar
	a[stateOK]['T'] = actionInfinityChar
	a[stateOK]['y'] = actionInfinityChar
	a[stateOK]['Y'] = actionInfinityChar

	// NaN: "nan" (case-insensitive).
	t[stateNaN]['a'] = stateNaN
	t[stateNaN]['A'] = stateNaN
	a[stateNaN]['a'] = actionNaNChar
	a[stateNaN]['A'] = actionNaNChar
	t[stateNaN]['n'] = stateOK
	t[stateNaN]['N'] = stateOK
	a[stateNaN]['n'] = actionNaNChar
	a[stateNaN]['N'] = actionNaNChar
}

func writeTables(root string, transitions [maxStates][alphabet]state, actions [maxStates][alphabet]action) error {
	var buf bytes.Buffer

	fmt.Fprintln(&buf, "package fsa")
	fmt.Fprintln(&buf)
	fmt.Fprintln(&buf, "// Code generated by internal/fsa/generate/gen_tables.go; DO NOT EDIT.")
	fmt.Fprintln(&buf)

	fmt.Fprintf(&buf, "var TransitionTable = [%d*%d]uint8{\n", maxStates, alphabet)
	for s := 0; s < maxStates; s++ {
		for ch := 0; ch < alphabet; ch++ {
			idx := s*alphabet + ch
			fmt.Fprintf(&buf, "\t%d: %d,\n", idx, transitions[s][ch])
		}
	}
	fmt.Fprintln(&buf, "}")
	fmt.Fprintln(&buf)

	fmt.Fprintf(&buf, "var ActionTable = [%d*%d]uint8{\n", maxStates, alphabet)
	for s := 0; s < maxStates; s++ {
		for ch := 0; ch < alphabet; ch++ {
			idx := s*alphabet + ch
			fmt.Fprintf(&buf, "\t%d: %d,\n", idx, actions[s][ch])
		}
	}
	fmt.Fprintln(&buf, "}")

	src, err := format.Source(buf.Bytes())
	if err != nil {
		return fmt.Errorf("format: %w", err)
	}

	outPath := filepath.Join("internal", "fsa", "transition_table.go")
	if err := os.WriteFile(outPath, src, 0o644); err != nil {
		return fmt.Errorf("write %s: %w", outPath, err)
	}
	return nil
}


