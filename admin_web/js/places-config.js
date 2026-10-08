// Geoapify API key — get one free at https://www.geoapify.com/ :
//   1. Sign up → "MyProjects" → create a project.
//   2. The project gets a default API key automatically (or add one).
//   3. In the key's settings, restrict allowed domains/referrers to
//      http://localhost:*/* so it can't be used from anywhere else.
//   4. Paste the key below, replacing the placeholder text.
//
// Free plan: 3,000 credits/day (~90,000/month) — far more than this
// console needs for occasional admin-triggered sweeps (see
// js/places-import.js). Unlike Google Places API, Geoapify's terms
// explicitly allow permanently storing/caching search results in your own
// database — that's *why* this console uses Geoapify instead of Google
// Places now. The only condition is attribution, which the import modal in
// admin/attractions.html already shows ("Data © OpenStreetMap
// contributors, via Geoapify") — keep that notice if you customise the UI.
export const GEOAPIFY_API_KEY = "4a7ab13c50b44573bdb16b4be226da6f";
