# AR Cemetery Navigator
### Bachelor Thesis
#### Op welke manier kan digitalisatie, in combinatie metaugmented reality, worden ingezet om de efficiëntievan het navigeren van een kerkhof te verbeteren? –een Proof of Concept

---

## Project Overview

This app demonstrates outdoor AR navigation in a cemetery. The user opens the app to an immediate live camera view (ARKit world tracking) with two key UI elements:

- **Bottom-left:** A minimap (MKMapView satellite view) showing the user's location and all grave markers. Tap to expand to fullscreen.
- **Bottom-right:** A search button for opening a search functionality, to search and filter for a persons grave.

When a grave is selected, the app:
1. Places a floating 3D annotation label in AR space at the grave's GPS coordinates.
2. Highlights the grave on the minimap with a pin.
3. Shows an info card at the bottom with the person's details.
4. Continuously updates the distance from the user to the grave.

--- 
