package dbus

import (
	"time"
)

// SubscriptionSet returns a subscription set which is like conn.Subscribe but
// can filter to only return events for a set of units.
type SubscriptionSet struct {
	*set
	conn *Conn
}

func (s *SubscriptionSet) filter(unit string) bool {
	return !s.Contains(unit)
}

// Subscribe starts listening for dbus events for all of the units in the set.
// Returns channels identical to conn.SubscribeUnits.
func (s *SubscriptionSet) Subscribe() (<-chan map[string]*UnitStatus, <-chan error) {
	// TODO: Make fully evented by using systemd 209 with properties changed values
	return s.conn.SubscribeUnitsCustom(time.Second, 0,
		mismatchUnitStatus,
		func(unit string) bool { return s.filter(unit) },
	)
}

// NewSubscriptionSet returns a new subscription set.
func (conn *Conn) NewSubscriptionSet() *SubscriptionSet {
	return &SubscriptionSet{newSet(), conn}
}

// mismatchUnitStatus returns true if the provided UnitStatus objects
// are not equivalent. false is returned if the objects are equivalent.
// Only the Name, Description and state-related fields are used in
// the comparison.
func mismatchUnitStatus(u1, u2 *UnitStatus) bool {
	return u1.Name != u2.Name ||
		u1.Description != u2.Description ||
		u1.LoadState != u2.LoadState ||
		u1.ActiveState != u2.ActiveState ||
		u1.SubState != u2.SubState
}
