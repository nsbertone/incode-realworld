// Each spec initialises the Angular TestBed itself (beforeAll), so this file
// only loads zone.js. Upstream also initialised TestBed here, which made every
// spec fail with "Cannot set base providers because it has already been called",
// and zone.js was missing from devDependencies; both fixed when importing.
import 'zone.js';
import 'zone.js/testing';
