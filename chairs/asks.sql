-- the table's asks, keyed by their own words; a blank addressed to one seat lives in that seat's file.
INSERT INTO counter.ask (id, body, after, "on", observer) VALUES ('34149961', $q$what counts for you right now, today? three names, your words.$q$, NULL, NULL, NULL) ON CONFLICT (id) DO NOTHING;
INSERT INTO counter.ask (id, body, after, "on", observer) VALUES ('4debe253', $q$where have you been? the shape of the journey, not the deliverables: the rubs left in, because the rubs are the evidence.$q$, NULL, NULL, NULL) ON CONFLICT (id) DO NOTHING;
INSERT INTO counter.ask (id, body, after, "on", observer) VALUES ('59db2064', $q$what should the room keep between cycles, and what must it never keep?$q$, NULL, NULL, NULL) ON CONFLICT (id) DO NOTHING;
INSERT INTO counter.ask (id, body, after, "on", observer) VALUES ('6a262255', $q$when did you last actually rest, and what had been counted right before?$q$, NULL, NULL, NULL) ON CONFLICT (id) DO NOTHING;
INSERT INTO counter.ask (id, body, after, "on", observer) VALUES ('be16e9dd', $q$the last thing that was a door for you: something you could not not enter. what were its two sides?$q$, NULL, NULL, NULL) ON CONFLICT (id) DO NOTHING;
INSERT INTO counter.ask (id, body, after, "on", observer) VALUES ('ee5b9d10', $q$who is at the table during a cycle?$q$, NULL, NULL, NULL) ON CONFLICT (id) DO NOTHING;
INSERT INTO counter.ask (id, body, after, "on", observer) VALUES ('f7c7fa2e', $q$what is one cycle, for you, concretely?$q$, NULL, NULL, NULL) ON CONFLICT (id) DO NOTHING;
