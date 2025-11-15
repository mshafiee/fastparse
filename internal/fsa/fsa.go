// Copyright 2025 Mohammad Shafiee. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package fsa

// State represents a parser state in the finite state automaton.
type State uint8

const (
	StateStart State = iota
	StateSign
	StateInteger
	StateDecimal
	StateFraction
	StateExponent
	StateExpSign
	StateExpDigits
	StateHexPrefix
	StateHexInteger
	StateHexDecimal
	StateHexFraction
	StateHexExpMarker
	StateHexExpSign
	StateHexExpDigits
	StateInfinity
	StateNaN
	StateOverflow
	StateUnderflow
	StateError
	StateOK
)

// MaxStates is the number of states in the automaton.
const MaxStates = 32

// Action represents an action to perform for a given transition.
//
// Actions are interpreted by higher-level parsers (e.g. accumulate digit,
// toggle sign, start exponent, etc).
type Action uint8

const (
	ActionNone Action = iota
	ActionSetSign
	ActionDigit
	ActionDot
	ActionExpMarker
	ActionHexPrefix
	ActionHexDigit
	ActionHexExpMarker
	ActionUnderscore
	ActionInfinityChar
	ActionNaNChar
)
